package main

// Copyright 2023 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//      http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import (
	"encoding/json"
	"fmt"
	"github.com/labstack/echo/v4"
	"github.com/micovery/apigee-app-sync/pkg/app_sync"
	"google.golang.org/api/apigee/v1"
	"io"
	"net/http"
)

func main() {
	e := echo.New()
	e.POST("/", func(c echo.Context) error {
		fmt.Printf("Received new request ...\n")

		var jsonBody []byte
		var err error

		if jsonBody, err = io.ReadAll(c.Request().Body); err != nil {
			panic(fmt.Errorf("could read request body"))
		}

		var method string
		if method, err = app_sync.DetectMethod(jsonBody); err != nil {
			return echo.NewHTTPError(http.StatusBadRequest, err.Error())
		}

		fmt.Printf("Detected method: %s\n", method)

		switch method {
		case app_sync.CreateAppMethod:
			fallthrough
		case app_sync.CreateAppKeyMethod:
			fallthrough
		case app_sync.UpdateAppMethod:
			fallthrough
		case app_sync.UpdateAppKeyMethod:
			var app *apigee.GoogleCloudApigeeV1DeveloperApp
			if app, err = app_sync.GetApigeeDeveloperApp(method, jsonBody); err != nil {
				return echo.NewHTTPError(http.StatusBadRequest, err.Error())
			}

			fmt.Printf("Found app: %s\n", app.Name)

			if _, err := app_sync.UpdateOrInsertKeycloakClient(app); err != nil {
				return echo.NewHTTPError(http.StatusBadRequest, err.Error())
			}
		default:
			return echo.NewHTTPError(http.StatusBadRequest, fmt.Sprintf("method %s not supported", method))
		}

		resBytes, _ := json.Marshal(map[string]string{
			"message": "complete",
		})

		res := string(resBytes)
		return c.String(http.StatusOK, res)
	})

	e.Logger.Fatal(e.Start(":8080"))
}
