# Mock Login microservice
This is a login microservice running on [mu.semte.ch](http://mu.semte.ch). The microservice provides the necessary endpoints to link the current session to a provided user and group.

## Getting started
### Add the mock-login service to your stack
Add the following snippet to your `docker-compose.yml`:

```
mock-login:
  image: kanselarij-vlaanderen/mock-login-service:2.4.0
```

Add rules to the `dispatcher.ex` to dispatch requests to the mock-login service:

```
  match "/mock/sessions/*path", %{ accept: [ :json ] } do
    Proxy.forward conn, path, "http://mock-login/sessions/"
  end
```

Add a migration that populates the triplestore with mock-accounts according to the authentication model.


## Reference

### Model

The data model is described in the [kaleidos-documentation repository](https://github.com/kanselarij-vlaanderen/kaleidos-documentation/blob/master/data-model/authentication.md).

### API

#### POST /sessions
Log in, i.e. create a new session for a mock-account

##### Request body
```javascript
data: {
   type: "sessions",
   relationships: {
     account:{
       data: {
         id: "8e38fb90-f15c-47e9-8d74-024a3112dd28",
         type: "accounts"
       }
     }
   }
}
```

##### Response
###### 201 Created
On successful login with the newly created session in the response body:

```javascript
{
  "links": {
    "self": "sessions/current"
  },
  "data": {
    "type": "sessions",
    "id": "b178ba66-206e-4551-b41e-4a46983912c0"
    "relationships": {
      "account": {
        "links": {
          "related": "/accounts/8e38fb90-f15c-47e9-8d74-024a3112dd28"
        },
        "data": {
          "type": "accounts",
          "id": "8e38fb90-f15c-47e9-8d74-024a3112dd28"
        }
      },
      "membership": {
        "links": {
          "related": "/memberships/3ba43eea-28f4-4386-bc26-2476baeb8425"
        },
        "data": {
          "type": "memberships",
          "id": "3ba43eea-28f4-4386-bc26-2476baeb8425"
        }
      }
    }
  }
}
```

###### 400 Bad Request
- if session header is missing. The header should be automatically set by the [identifier](https://github.com/mu-semtech/mu-identifier).
- if the account doesn't exist

###### 401 Forbidden
- if the user or membership has been blocked

#### DELETE /sessions/current
Log out the current user, i.e. remove the session associated with the current user's account.

##### Response
###### 204 No Content
On successful logout

###### 400 Bad Request
If session header is missing or invalid. The header should be automatically set by the [identifier](https://github.com/mu-semtech/mu-identifier).
