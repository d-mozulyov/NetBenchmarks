package main

import (
	"net/http"
	"strconv"

	"./servers"
)

func handler_blank(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", servers.TEXT_CONTENT)
	w.Write([]byte(servers.BLANK_RESPONSE))
}

func handler_work(w http.ResponseWriter, r *http.Request) {
	w.Header().Set("Content-Type", servers.JSON_CONTENT)
	w.Write(servers.ProcessJson(r.Body))
}

func main() {

	servers.Initialize("HTTP")

	if !servers.WORK_MODE {
		// blank mode
		http.HandleFunc("/", handler_blank)
	} else {
		// work mode
		http.HandleFunc("/", handler_work)
	}
	http.ListenAndServe(":"+strconv.Itoa(servers.SERVER_PORT), nil)
}
