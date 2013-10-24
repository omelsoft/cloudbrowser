// Generated by CoffeeScript 1.6.3
(function() {
  var EventEmitter, User;

  EventEmitter = require('events').EventEmitter;

  User = (function() {
    function User(user) {
      this.name = user;
      this.joinedRooms = [];
      this.otherRooms = [];
      this.currentRoom = null;
    }

    User.prototype.getName = function() {
      return this.name;
    };

    User.prototype.activateRoom = function(room) {
      return this.currentRoom = room;
    };

    User.prototype.deactivateRoom = function() {
      return this.currentRoom = null;
    };

    User.prototype.join = function(room, newMessageHandler) {
      if (this.joinedRooms.indexOf(room) === -1) {
        this.removeFromOtherRooms(room);
        this.joinedRooms.push(room);
        room.on('newMessage', newMessageHandler);
      }
      return this.activateRoom(room);
    };

    User.prototype.leave = function(room) {
      var idx;
      idx = this.joinedRooms.indexOf(room);
      if (idx !== -1) {
        this.joinedRooms.splice(idx, 1);
      }
      this.addToOtherRooms(room);
      if (this.currentRoom === room) {
        if (this.joinedRooms.length) {
          return this.activateRoom(this.joinedRooms[0]);
        } else {
          return this.deactivateRoom();
        }
      }
    };

    User.prototype.removeFromOtherRooms = function(room) {
      var idx;
      idx = this.otherRooms.indexOf(room);
      if (idx !== -1) {
        return this.otherRooms.splice(idx, 1);
      }
    };

    User.prototype.addToOtherRooms = function(room) {
      if (this.otherRooms.indexOf(room) === -1) {
        return this.otherRooms.push(room);
      }
    };

    return User;

  })();

  module.exports = User;

}).call(this);
