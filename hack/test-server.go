package main

import (
	"encoding/json"
	"log"
	"net/http"
)

type Role struct {
	AccountID string `json:"accountId"`
	PartyID   string `json:"partyId"`
}

type RoleScopesResponse struct {
	Role   Role     `json:"role"`
	Scopes []string `json:"scopes"`
}

func main() {

	rsr := RoleScopesResponse{
		Role{
			AccountID: "cfbfbb5a-8b0a-427d-a05e-8d78147605d0",
			PartyID:   "f9e6a782-93c8-590a-8392-0fef2528c504",
		},
		[]string{"urn:uplight:connect:bills:read",
			"urn:uplight:connect:service_locations:read"},
	}

	http.HandleFunc("/v1/roleScopes", func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "application/json")
		json.NewEncoder(w).Encode(rsr)
	})

	log.Fatal(http.ListenAndServe(":8081", nil))

}
