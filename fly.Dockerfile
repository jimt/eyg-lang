FROM ghcr.io/gleam-lang/gleam:v0.25.3-node

COPY . /opt/app
WORKDIR /opt/app/eyg
RUN npm install
RUN gleam run build
RUN npx rollup -f iife -i ./build/dev/javascript/eyg/bundle.js -o public/bundle.js
RUN gleam run web
