package main

import (
	"bytes"
	"context"
	"encoding/json"
	"io/ioutil"
	"log"
	"net/http"
	"os"
	"time"

	"golang.org/x/oauth2"
	"google.golang.org/api/idtoken"
	"gopkg.in/yaml.v2"
)

type appConfig struct {
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

func main() {
	configPath := "/etc/homeauto-api/config.yaml"

	var config appConfig
	f, err := os.Open(configPath)
	if err != nil {
		panic(err)
	}
	decoder := yaml.NewDecoder(f)
	err = decoder.Decode(&config)

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
