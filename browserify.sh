#!/bin/sh

browserify --bare -t uglifyify lib/xq.js >lib/xq.min.js
