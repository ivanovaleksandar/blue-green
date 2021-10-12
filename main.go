package main

import (
	"fmt"
	"log"
	"net/http"
	"os"
)

func main() {
	http.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprintf(w, "Hello, this is the %s deployment", os.Getenv("DEPLOYMENT"))
	})

	log.Fatal(http.ListenAndServe(":3000", nil))
}
