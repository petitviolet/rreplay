# Example for Rack::Rreplay using Sinatra

## Run

```console
$ bundle exec rackup -p 4567
```

## Send a request

```console
$ curl 'localhost:4567/?hoge=foo&a=b' \
  -H "Content-Type: xxx" \
  -b "key=value" \
  -H "ACCESS_TOKEN: hogehoge"
```
