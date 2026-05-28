# payment

This is a sample GoLang app for payments

# Endpoints

App is running on port 8080

There are 3 endpoints:

GET /payment/:id - retrieve payment by id
POST /payment - create a new payment body json:
{
    "reference": "1",
    "volume": "1000.20",
    "currency": "USD"
}
# How to build

Host

Check if you have go go version or install it
Run go build .. The file will be located in this dir payment or you can run go build -o <bin-name> to output binary with different name
Dockerfile

Use golang:1.24.2 as a base image for build
Copy go.mod and go.sum and run go mod download
Copy all files inside and run go build . or you can run go build -o <bin-name> to output binary with different name
Prepare a running image. You can use FROM alpine.
Copy binary from build to run and configure entrypoint to just run your binary
How to run

You need to setup PAYMENT_PORT env variable to change default port. By default it runs on 8080 port.

You need just run your binary
