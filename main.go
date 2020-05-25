package main

import (
	"encoding/json"
	"fmt"
	"io/ioutil"
	"path"
	"runtime"
	"time"

	"github.com/dgrijalva/jwt-go"
)

func register() {
	_, filename, _, _ := runtime.Caller(0)
	credentialsPath := path.Dir(filename) + "/config/credentials.json"
	b, _ := ioutil.ReadFile(credentialsPath)
	var j struct {
		ClientID     string `json:"client_id"`
		ClientEmail  string `json:"client_email"`
		PrivateKeyID string `json:"private_key_id"`
		PrivateKey   string `json:"private_key"`
	}

	json.Unmarshal(b, &j)
	signKey, _ := jwt.ParseRSAPrivateKeyFromPEM([]byte(j.PrivateKey))

	type GCPClaims struct {
		AZP           string `json:"azp"`
		Email         string `json:"email"`
		EmailVerified bool   `json:"email_verified"`
		jwt.StandardClaims
	}

	// Create the Claims
	claims := GCPClaims{
		j.ClientEmail,
		j.ClientEmail,
		true,
		jwt.StandardClaims{
			Audience:  "32555940559.apps.googleusercontent.com",
			Issuer:    "https://accounts.google.com",
			ExpiresAt: 1590364208,
			IssuedAt:  1590360608,
			Subject:   j.ClientID,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodRS256, claims)
	token.Header["kid"] = j.PrivateKeyID
	ss, _ := token.SignedString(signKey)
	fmt.Printf("%v", ss)
}

func main() {
	register()
	registerTimer := time.NewTicker(5 * time.Second)
	for {
		select {
		case <-registerTimer.C:
			register()
		}
	}
}
