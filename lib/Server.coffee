# We create uuids
uuid = require 'node-uuid'
async = require 'async'

# Include ws, a fast websocket server
WebSocketServer = (require "ws").Server

# We are going to use protobufs for this
fs = require 'fs'
path = require 'path'
Schema = (require 'protobuf').Schema
proto = path.resolve(require.resolve('pocket.proto'), '../pocket.desc')
schema = new Schema fs.readFileSync proto

# Setup the protobuf types
Request = schema['pocket.Request']

# message types
types = require './types'
DEBUG = true

# Our Shuffle function
shuffle = (a) ->
  i = a.length
  while --i > 0
    j = ~~(Math.random() * (i + 1))
    t = a[j]
    a[j] = a[i]
    a[i] = t
  a

class Server
  constructor: (options={}) ->
    @channels = {}
    @clients  = {}

    @_server_events = {}
    @_auth_fn = (key, verifier, cb) -> cb null, no
    @_global_channels = []

    @_uuid_to_api_key

    @port   = options.port || 8080
    @host   = options.host || '127.0.0.1'
    @secure = options.secure || no

    @server = new WebSocketServer(port: @port)

    # bind the events to the server
    server = @
    @server.on "connection", (socket) ->
      server._connection.apply(@, [socket, server])

  auth: (fn) ->
    @_auth_fn = fn

  set_global_channels: (channels) ->
    @_global_channels = channels

  # Listen to server events
  on: (event, fn) ->
    if @_server_events[event]
      @_server_events[event].push fn
    else
      @_server_events[event] = [fn]

  # Send information to a channel
  emit: (channel, data) ->
    if @channels[channel.toLowerCase()]
      iter=0
      chans = shuffle(@channels[channel.toLowerCase()])
      async.each chans, (uuid, cb) ->
        # Send the data
        s = (client) ->
          client.send data, binary: yes
          do cb

        iter++
        if iter > 500
          iter = 0
          setImmediate =>
            s(@clients[uuid])
        else
          s(@clients[uuid])

  _do: (event, self, params) ->
    if @_server_events[event]
      async.each @_server_events[event], (fn, cb) ->
        fn.apply self, params
        do cb


  _connection: (socket, server) ->
    # do the connection event
    server._do 'connection', server, [socket]

    socket.channels = []
    socket.on 'message', (message, flags) ->
      # do the message event
      server._do 'raw_message', @, [message, flags]
      server._message.apply(@, [message, flags, server])

    socket.on 'close', ->
      server._do 'close', @, []
      server._close.call(@, server)

  _close: (server) ->
    # cleanup clients
    delete server.clients[@uuid]

    async.each @channels, (chan, cb) ->
      server.channels[chan].splice(server.channels[chan].indexOf(@uuid), 1)
      if not server.channels[chan].length then delete server.channels[chan]

      do cb

  _message: (message, flags, server) ->
    # All requests should be binary. No reason
    # to go further if it isn't
    if !flags.binary then return @close()

    # Try to parse the protobuf request
    # Return if an error occurs
    try
      r = Request.parse(message)
    catch e
      return False

    # If this is a malformed request
    if !r.request_type then return @close()

    # Close the server if they haven't authenticated and this
    # isn't a request to authenticate
    if not @uuid and r.request_type is not types.AUTH then return @close()

    # Fire the auth event, with the request
    server._do r.request_type.toLowerCase(), @, [r]

    make_chan_name = (globals, uuid, chan) ->
      # lowercase
      chan = chan.toLowerCase()

      # namespace the channel if it isn't global
      if not (chan in globals)
        chan = uuid+'.'+chan

      # return it
      return chan

    switch r.request_type
      # An authentication attempt
      when types.AUTH
        # Make sure that the attempt is valid
        if r.auth and r.auth.key and r.auth.verifier
          # call the server auth function. This is set by the code
          # running the server
          server._auth_fn r.auth.key, r.auth.verifier, (err, auth) =>
            if !err and auth
              # If a connection is authed, give them a UUID
              # This will be unique per socket connection
              @uuid = r.auth.key+''+uuid.v1()
              @send 'ack'
              server.clients[@uuid] = @
            else
              @close()
        else
          # if the message isn't well formed, close the socket
          console.log 'Malformed Auth, closing socket' if DEBUG
          @close()
      when types.JOIN
        if r.channel and r.channel.name
          # all channels are lowercase
          chan = make_chan_name server._global_channels, @uuid, r.channel.name

          if not (chan in @channels)
            @channels.push(chan)
            if server.channels[chan]
              server.channels[chan].push(@uuid)
            else
              server.channels[chan] = [@uuid]

      when types.LEAVE
        if r.channel and r.channel.name
          chan = make_chan_name server._global_channels, @uuid, r.channel.name
          if chan in @channels
            @channels.splice(@channels.indexOf(chan), 1)
            server.channels[chan].splice(server.channels[chan].indexOf(@uuid), 1)
            if not server.channels[chan].length then delete server.channels[chan]

      when types.MESSAGE
        server._do 'message', @, [message]

exports.Server = Server
