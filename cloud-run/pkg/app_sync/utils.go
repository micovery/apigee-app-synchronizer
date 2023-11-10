package app_sync

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
	"context"
	"encoding/json"
	"fmt"
	"github.com/Nerzal/gocloak/v13"
	"google.golang.org/api/apigee/v1"
	"os"
	"regexp"
	"strings"
)

func UpdateOrInsertKeycloakClient(app *apigee.GoogleCloudApigeeV1DeveloperApp) ([]string, error) {
	envs := map[string]string{}

	//validate env-vars are set
	requiredEnvs := []string{KeycloakUrlEnv, KeycloakAdminEnv, KeycloakAdminPasswordEnv, KeycloakAdminRealmEnv, KeycloakApigeeRealmEnv}
	for _, requiredEnv := range requiredEnvs {
		envs[requiredEnv] = os.Getenv(requiredEnv)
		if envs[requiredEnv] == "" {
			return nil, fmt.Errorf("%s is required", requiredEnv)
		}
	}

	client := gocloak.NewClient(envs[KeycloakUrlEnv])
	ctx := context.Background()

	var err error
	var token *gocloak.JWT
	if token, err = client.LoginAdmin(ctx, envs[KeycloakAdminEnv], envs[KeycloakAdminPasswordEnv], envs[KeycloakAdminRealmEnv]); err != nil {
		return nil, err
	}

	var clients []string
	for _, creds := range app.Credentials {
		var err error
		//update client if it exists
		var kClients []*gocloak.Client

		if kClients, err = client.GetClients(ctx, token.AccessToken, envs[KeycloakApigeeRealmEnv], gocloak.GetClientsParams{ClientID: &creds.ConsumerKey}); err != nil {
			fmt.Printf("could not find client %s. error: %s\n", creds.ConsumerKey, err.Error())
			continue
		}

		if len(kClients) > 0 {
			fmt.Printf("found existing client with id: %s\n", creds.ConsumerKey)

			kClient := kClients[0]
			kClient.Secret = gocloak.StringP(creds.ConsumerSecret)
			kClient.RedirectURIs = &[]string{}

			if app.CallbackUrl != "" {
				callbackUrls := append(*kClient.RedirectURIs, app.CallbackUrl)
				kClient.RedirectURIs = &callbackUrls
			}

			fmt.Printf("updating existing client with id: %s\n", creds.ConsumerKey)

			if err := client.UpdateClient(ctx, token.AccessToken, envs[KeycloakApigeeRealmEnv], *kClient); err != nil {
				fmt.Printf("could not update client %s. error: %s\n", err.Error())
				continue
			}

			clients = append(clients, *kClient.ClientID)

		} else {

			fmt.Printf("could not find existing client with id: %s\n", creds.ConsumerKey)

			//create new client
			kClient := gocloak.Client{
				Name:         gocloak.StringP(app.Name),
				ClientID:     gocloak.StringP(creds.ConsumerKey),
				Secret:       gocloak.StringP(creds.ConsumerSecret),
				RedirectURIs: &[]string{},
				WebOrigins:   &[]string{"+"},
			}

			if app.CallbackUrl != "" {
				callbackUrls := append(*kClient.RedirectURIs, app.CallbackUrl)
				kClient.RedirectURIs = &callbackUrls
			}

			fmt.Printf("creating new client with id: %s\n", creds.ConsumerKey)

			var clientId string
			if clientId, err = client.CreateClient(ctx, token.AccessToken, envs[KeycloakApigeeRealmEnv], kClient); err != nil {
				fmt.Printf("could not create client. error: %s\n", err.Error())
				continue
			}
			clients = append(clients, clientId)
		}
	}

	return clients, nil
}

func DetectMethod(jsonBody []byte) (string, error) {
	info := EventInfo{}
	json.Unmarshal(jsonBody, &info)

	methodName := info.MethodName()
	if methodName == "" {
		return "", fmt.Errorf("could not detect operation")
	}

	parts := strings.Split(methodName, ".")

	return parts[len(parts)-1], nil
}

func GetApigeeDeveloperApp(method string, jsonBody []byte) (*apigee.GoogleCloudApigeeV1DeveloperApp, error) {
	ctx := context.Background()
	var err error
	var path string
	if path = getAppPath(method, jsonBody); path == "" {
		return nil, fmt.Errorf("could not determine app path from event")
	}

	var apigeeService *apigee.Service
	if apigeeService, err = apigee.NewService(ctx); err != nil {
		return nil, fmt.Errorf("could not create Apigee service")
	}

	var app *apigee.GoogleCloudApigeeV1DeveloperApp
	if app, err = apigeeService.Organizations.Developers.Apps.Get(path).Do(); err != nil {
		return nil, fmt.Errorf("could not find app. %s", err.Error())
	}
	return app, nil
}

func getAppPath(method string, jsonBody []byte) string {

	appPath := ""

	if method == CreateAppMethod {
		data := CreateAppEventData{}
		json.Unmarshal(jsonBody, &data)
		appPath = fmt.Sprintf("%s/apps/%s", data.ProtoPayload.Request.Parent, data.ProtoPayload.Request.DeveloperApp.Name)
	} else if method == UpdateAppMethod {
		data := UpdateAppEventData{}
		json.Unmarshal(jsonBody, &data)
		appPath = data.ProtoPayload.Request.Name
	} else if method == CreateAppKeyMethod {
		data := CreateAppKeyEventData{}
		json.Unmarshal(jsonBody, &data)
		appPath = data.ProtoPayload.Request.Parent
	} else if method == UpdateAppKeyMethod {
		data := UpdateAppKeyEventData{}
		json.Unmarshal(jsonBody, &data)
		appPath = data.ProtoPayload.Request.Name
		re := regexp.MustCompile("\\/keys\\/.+$")
		appPath = re.ReplaceAllString(appPath, "")
	}

	fmt.Printf("Detected app path: %s\n", appPath)
	return appPath
}
