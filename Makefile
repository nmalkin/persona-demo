all: app docs

docs: src/server.litcoffee src/client.litcoffee README.md
	docco -l linear README.md src/client.litcoffee src/server.litcoffee

app/server.js: src/server.litcoffee
	coffee -c -o app/ src/server.litcoffee

app/public/client.js: src/client.litcoffee
	coffee -c -o app/public src/client.litcoffee

app: app/server.js app/public/client.js

app/node_modules:
	cd app && npm install

install: app/node_modules

run: app/server.js app/public/client.js install
	node app/server.js
