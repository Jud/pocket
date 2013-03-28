# Pocket
## Websocket PubSub for Humans

### Features
- Simple protocol
- Utilizes Google Protocol Buffers for speed
- Add more features

### Examples
```coffees
# Import the pocket server
{Server} = require 'pocket'

# Import your extension of the pocket .proto files
# They can be found at [jud/pocket.proto](https://github.com/Jud/pocket.proto)
fs = require 'fs'
path = require 'path'
{Schema} = require 'protobuf'
schema = new Schema fs.readFileSync path.resolve(__dirname,'./protocol.desc')

# Our stuff
Request = schema['Request']

s = new Server
s.on 'raw_message', (r) ->
  # This is triggered any time a request is processed
  # even if it is handled internally by the pocket server.
  # Internally handled requests include: JOIN, LEAVE, AUTH

s.on 'message', (r) ->
  # This event only fires for messages that your application
  # should handle. The user must already be AUTH'd. Because Pocket
  # doesn't know about your protobuf definitions, the request passed
  # to this function is in raw, binary form.
  try
    request = Request.parse(r)
  catch e
    # Fail
  
  # Do something with `request`
```

### Why Use Pocket?
** Good reason goes here ***

### License
Copyright (c) 2013 Judson Stephenson

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
