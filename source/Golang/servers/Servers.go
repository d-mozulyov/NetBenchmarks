package servers

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strconv"
	"strings"
	"time"
)

var SERVER_PORT = 1234
var WORK_MODE = false
var TEXT_CONTENT = "text/plain"
var JSON_CONTENT = "application/json"
var BLANK_RESPONSE = "OK"

const JsonDateFormat = "2006-01-02T15:04:05.999Z"

type JsonDate struct {
	time.Time
}

func (c *JsonDate) UnmarshalJSON(b []byte) (err error) {
	s := strings.Trim(string(b), `"`) // remove quotes
	if s == "null" {
		return
	}
	c.Time, err = time.Parse(JsonDateFormat, s)
	return
}

func (c JsonDate) MarshalJSON() ([]byte, error) {
	if c.Time.IsZero() {
		return nil, nil
	}
	return []byte(fmt.Sprintf(`"%s"`, c.Time.Format(JsonDateFormat))), nil
}

type RequestGroup struct {
	Kind    string     `json:"kind"`
	Default bool       `json:"default"`
	Balance float64    `json:"balance"`
	Dates   []JsonDate `json:"dates"`
}

type Request struct {
	Product   string       `json:"product"`
	RequestId string       `json:"requestId"`
	Group     RequestGroup `json:"group"`
}

type ResponseClient struct {
	Balance float64  `json:"balance"`
	MinDate JsonDate `json:"minDate"`
	MaxDate JsonDate `json:"maxDate"`
}

type Response struct {
	Product   string         `json:"product"`
	RequestId string         `json:"requestId"`
	Client    ResponseClient `json:"client"`
}

func ProcessJson(body io.ReadCloser) []byte {
	// request
	var request Request
	err := json.NewDecoder(body).Decode(&request)
	if err != nil {
		return nil
	}

	// min/max
	minDate, err := time.Parse(JsonDateFormat, "9999-12-31T23:59:59.999Z")
	maxDate, err := time.Parse(JsonDateFormat, "0000-01-01T00:00:00.000Z")
	for _, d := range request.Group.Dates {
		if d.Time.Before(minDate) {
			minDate = d.Time
		}
		if d.Time.After(maxDate) {
			maxDate = d.Time
		}
	}

	// response
	var response Response
	response.Product = request.Product
	response.RequestId = request.RequestId
	response.Client.Balance = request.Group.Balance
	response.Client.MinDate.Time = minDate
	response.Client.MaxDate.Time = maxDate
	result, err := json.Marshal(response)
	return result
}

func Initialize(Protocol string) {

	if len(os.Args) > 1 {
		if os.Args[1] == "1" {
			WORK_MODE = true
		}
		if os.Args[1] == "0" {
			WORK_MODE = false
		}
	}

	var mode_name = "blank"
	if WORK_MODE {
		mode_name = "work"
	}
	fmt.Println("Golang." + Protocol + " (" + mode_name + " mode) port " + strconv.Itoa(SERVER_PORT) + " listening...")
}
