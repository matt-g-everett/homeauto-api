package main

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"os/signal"
	"time"

	"github.com/gorilla/mux"
	"golang.org/x/oauth2"
	"google.golang.org/api/idtoken"
	"gopkg.in/yaml.v2"
)

type appConfig struct {
	Port             int32  `json:"port"`
	RegisterFunction string `yaml:"registerFunction"`
	ClientID         string `yaml:"clientId"`
}

type registrar struct {
	config appConfig
}

type registerBody struct {
	IP string `json:"ip"`
}

func newRegistrar(config appConfig) *registrar {
	r := new(registrar)
	r.config = config

	return r
}

func (r *registrar) getWanIP() (string, error) {
	ip := []byte(nil)
	resp, err := http.Get("https://api.ipify.org")
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	ip, err = ioutil.ReadAll(resp.Body)
	return string(ip), err
}

func (r *registrar) createIdentityToken() (*oauth2.Token, error) {
	credentialsPath := "/etc/homeauto-api/credentials.json"

	// Generate an identity token where the kid (private key id) matches the kid available
	// in certificate 1 from here: https://www.googleapis.com/oauth2/v3/certs
	aud := r.config.ClientID
	ctx := context.Background()
	ts, err := idtoken.NewTokenSource(ctx, aud, idtoken.WithCredentialsFile(credentialsPath))
	if err != nil {
		log.Printf("Failed to create TokenSource: %v", err)
		return nil, err
	}
	tok, err := ts.Token()
	return tok, err
}

func (r *registrar) callRegister(ip string, token oauth2.Token) {
	data := registerBody{ip}
	body, _ := json.Marshal(data)

	client := &http.Client{}
	req, err := http.NewRequest("POST", r.config.RegisterFunction,
		bytes.NewBuffer(body))
	if err != nil {
		log.Printf("Failed to create request for register cloud function: %v", err)
		return
	}
	req.Header.Add("Content-type", "application/json")
	req.Header.Add("Authorization", "Bearer "+token.AccessToken)
	resp, err := client.Do(req)
	if err != nil {
		log.Printf("Failed to call register cloud function: %v", err)
		return
	}
	defer resp.Body.Close()

	if resp.StatusCode != 200 {
		log.Printf("register cloud function failed with response code %d", resp.StatusCode)
		return
	}

	log.Printf("Set IP for homeauto-api to %s", ip)
}

func (r *registrar) register() {
	token, err := r.createIdentityToken()
	if err != nil {
		log.Printf("Failed to create identity token: %v", err)
		return
	}

	ip, err := r.getWanIP()
	if err != nil {
		log.Printf("Failed to get WAN IP: %v", err)
		return
	}
	log.Printf("Discovered WAN IP: %s\n", ip)
	r.callRegister(ip, *token)
}

type hit struct {
	Source struct {
		ID   string  `json:"id"`
		Temp float32 `json:"temp"`
	} `json:"_source"`
}

type elasticResponse struct {
	Hits struct {
		Hits []hit `json:"hits"`
	} `json:"hits"`
}

type envResponseBody struct {
	PoolTemp  float32 `json:"poolTemp"`
	ShadeTemp float32 `json:"shadeTemp"`
	SunTemp   float32 `json:"sunTemp"`
}

func environmentHandler(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	if r.Method == "GET" {
		query := `{
	"query": {
		"match_all": {}
	},
	"size": 10,
	"sort": [
		{
			"@timestamp": {
				"order": "desc"
			}
		}
	]
}`
		resp, err := http.Post("http://elasticsearch-master:9200/logstash-*/_search", "application/json",
			bytes.NewBufferString(query))
		if err != nil {
			log.Printf("Failed to query temperatures from elasticsearch")
			w.WriteHeader(http.StatusServiceUnavailable)
			return
		}
		defer resp.Body.Close()
		respBody, err := ioutil.ReadAll(resp.Body)
		log.Printf("respBody: %s", string(respBody))
		if err != nil {
			log.Printf("Failed to read elasticsearch response body")
			w.WriteHeader(http.StatusInternalServerError)
			return
		}
		var esResp elasticResponse
		json.Unmarshal(respBody, &esResp)
		log.Printf("esRes: %v", esResp)

		bodyData := envResponseBody{32.4, 22.3, 35.13}
		body, _ := json.Marshal(bodyData)
		w.Write(body)
	}
}

func runAPI(config appConfig) {
	r := mux.NewRouter()
	r.HandleFunc("/api/environment", environmentHandler).Methods("GET", "HEAD")
	http.Handle("/", r)

	srv := &http.Server{
		Addr: fmt.Sprintf("0.0.0.0:%d", config.Port),
		// Good practice to set timeouts to avoid Slowloris attacks.
		WriteTimeout: time.Second * 15,
		ReadTimeout:  time.Second * 15,
		IdleTimeout:  time.Second * 60,
		Handler:      r, // Pass our instance of gorilla/mux in.
	}

	// Run our server in a goroutine so that it doesn't block.
	go func() {
		if err := srv.ListenAndServe(); err != nil {
			log.Println(err)
		}
	}()

	c := make(chan os.Signal, 1)
	// We'll accept graceful shutdowns when quit via SIGINT (Ctrl+C)
	// SIGKILL, SIGQUIT or SIGTERM (Ctrl+/) will not be caught.
	signal.Notify(c, os.Interrupt)

	// Block until we receive our signal.
	<-c

	// Create a deadline to wait for.
	ctx, cancel := context.WithTimeout(context.Background(), time.Second*15)
	defer cancel()
	// Doesn't block if no connections, but will otherwise wait
	// until the timeout deadline.
	srv.Shutdown(ctx)
	// Optionally, you could run srv.Shutdown in a goroutine and block on
	// <-ctx.Done() if your application should wait for other services
	// to finalize based on context cancellation.
	log.Println("shutting down")
	os.Exit(0)
}

func runRegistration(config appConfig) {
	registrar := newRegistrar(config)
	registrar.register()
	registerTimer := time.NewTicker(300 * time.Second)
	for {
		select {
		case <-registerTimer.C:
			registrar.register()
		}
	}
}

func main() {
	configPath := "/etc/homeauto-api/config.yaml"
	f, err := os.Open(configPath)
	if err != nil {
		panic(err)
	}
	var config appConfig
	decoder := yaml.NewDecoder(f)
	err = decoder.Decode(&config)

	go runRegistration(config)
	runAPI(config)
}
