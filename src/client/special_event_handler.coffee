EventTypeToGroup = require('./shared/event_lists').eventTypeToGroup
Config           = require('./shared/config')

class SpecialEventHandler
    constructor : (monitor) ->
        @monitor = monitor
        @socket = monitor.socket
        @_pendingKeyup = false
        @_queuedKeyEvents = []

    click : (remoteEvent, clientEvent, id) ->
        clientEvent.preventDefault()
        @socket.emit('processEvent',
                     remoteEvent,
                     @monitor.client.getSpecificValues(),
                     id)

    # Valid targets:
    #   input, select, textarea
    #
    change : (remoteEvent, clientEvent, id) ->
        target = clientEvent.target
        if target.clientSpecific
            return
        # TODO: use batch mechanism once it exists...this is inefficient.
        if target.tagName.toLowerCase() == 'select'
            if target.multiple == true
                for option in target.options
                    @socket.emit('setAttribute',
                                 option.__nodeID,
                                 'selected',
                                 option.selected)
            else
                @socket.emit('setAttribute',
                             clientEvent.target.__nodeID,
                             'selectedIndex',
                             clientEvent.target.selectedIndex)
        else # input or textarea
            @socket.emit('setAttribute',
                         clientEvent.target.__nodeID,
                         'value',
                         clientEvent.target.value)
        @socket.emit('processEvent', remoteEvent, @monitor.client.getSpecificValues(), id)

    keyup : (rEvent, event, id) =>
        @_pendingKeyup = false
        # Called directly as an event listener.
        if arguments.length != 3
            if Config.monitorLatency
                id = @monitor.client.latencyMonitor.start('keyup')
            event = rEvent
            rEvent = {}
            @monitor.eventInitializers[EventTypeToGroup[event.type]](rEvent, event)
        {target} = event
        @socket.emit('setAttribute',
                     target.__nodeID,
                     'value',
                     target.value)
        @_queuedKeyEvents.push([rEvent, id])
        for ev in @_queuedKeyEvents
            @socket.emit('processEvent',
                         ev[0], # event
                         @monitor.client.getSpecificValues(),
                         ev[1]) # id
        @_queuedKeyEvents = []
        if !@monitor.registeredEvents['keyup']
            @monitor.document.removeEventListener('keyup', @keyup, true)

    keydown : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    keypress : (remoteEvent, clientEvent, id) ->
        @_keyHelper(remoteEvent, id)

    _keyHelper : (remoteEvent, id) ->
        if !@_pendingKeyup && !@monitor.registeredEvents['keyup']
            @_pendingKeyup = true
            @monitor.document.addEventListener('keyup', @keyup, true)
        @_queuedKeyEvents.push([remoteEvent, id])

module.exports = SpecialEventHandler
