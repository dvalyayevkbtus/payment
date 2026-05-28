package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"time"

	log "github.com/sirupsen/logrus"
)

var (
	StatusCreated         = "CREATED"
	StatusPartiallyFilled = "PARTIALLY_FILLED"
	StatusFulfilled       = "FULFILLED"
)

var invoices map[string]Invoice = make(map[string]Invoice)

type InvoiceCreated struct {
	Reference string `json:"reference"`
	Volume    string `json:"volume"`
	Currency  string `json:"currency"`
}

type Invoice struct {
	Reference       string       `json:"reference"`
	Volume          string       `json:"volume"`
	Currency        string       `json:"currency"`
	VolumeFulfilled string       `json:"volumeFulfilled"`
	Status          string       `json:"status"`
	Confirments     []Confirment `json:"confirments"`
}

type Confirment struct {
	Reference   string `json:"reference"`
	Volume      string `json:"volume"`
	Currency    string `json:"currency"`
	AccountCode string `json:"accountCode"`
}

func main() {
	log.SetFormatter(&log.JSONFormatter{})
	log.SetOutput(os.Stdout)
	log.SetLevel(log.InfoLevel)

	http.HandleFunc("/payment", createPayment)
	http.HandleFunc("/payment/{id}", retrievePayment)

	log.Info("Payment service has started.")

	port := os.Getenv("PAYMENT_PORT")
	if port == "" {
		port = "8080"
	}
	http.ListenAndServe(fmt.Sprintf(":%s", port), nil)
}

func retrievePayment(rw http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodGet {
		rw.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	reference := req.PathValue("id")
	result, ok := invoices[reference]
	if !ok {
		rw.WriteHeader(http.StatusNotFound)
		return
	}
	marshalled, err := json.Marshal(result)
	if err != nil {
		log.Error(err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}
	_, err = rw.Write(marshalled)
	if err != nil {
		log.Error(err)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}
}

func createPayment(rw http.ResponseWriter, req *http.Request) {
	if req.Method != http.MethodPost {
		rw.WriteHeader(http.StatusMethodNotAllowed)
		return
	}
	body, bErr := io.ReadAll(req.Body)
	if bErr != nil {
		log.Error(bErr)
		rw.WriteHeader(http.StatusInternalServerError)
		return
	}
	var invoice InvoiceCreated
	mErr := json.Unmarshal(body, &invoice)
	if mErr != nil {
		log.Error(bErr)
		rw.WriteHeader(http.StatusBadRequest)
		return
	}
	invoices[invoice.Reference] = Invoice{invoice.Reference, invoice.Volume, invoice.Currency, "0.0",
		StatusCreated, make([]Confirment, 0)}
	rw.WriteHeader(http.StatusAccepted)
	log.Infof("Invoice %s created.", invoice.Reference)
	go func() {
		fulfill(invoice.Reference)
	}()
}

func fulfill(reference string) {
	time.Sleep(5 * time.Second)
	invoice, ok := invoices[reference]
	if !ok {
		return
	}
	invoice.Confirments = append(invoice.Confirments,
		Confirment{invoice.Reference, invoice.Volume, invoice.Currency, "KZ123456789012345678"})
	invoice.Status = StatusFulfilled
	invoices[reference] = invoice
	log.Infof("Invoce %s fulfilled.", reference)
}
