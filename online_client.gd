extends Node
class_name OnlineClient

signal event_received(message: Dictionary)
var socket := WebSocketPeer.new()
var connected := false
var url := "wss://ludo-sarvar1-1.onrender.com"

func connect_to_server(server_url: String) -> int:
    url = server_url.strip_edges()
    var err := socket.connect_to_url(url)
    connected = err == OK
    return err

func _process(_delta):
    socket.poll()
    var state := socket.get_ready_state()
    if state == WebSocketPeer.STATE_OPEN:
        connected = true
        while socket.get_available_packet_count() > 0:
            var parsed = JSON.parse_string(socket.get_packet().get_string_from_utf8())
            if parsed is Dictionary: event_received.emit(parsed)
    elif state == WebSocketPeer.STATE_CLOSED:
        connected = false

func send_message(data: Dictionary):
    if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
        socket.send_text(JSON.stringify(data))

func create_room(player_name: String, avatar: int = 0): send_message({"type":"create","name":player_name,"avatar":avatar})
func join_room(room: String, player_name: String, avatar: int = 0): send_message({"type":"join","room":room.to_upper(),"name":player_name,"avatar":avatar})
func start_game(): send_message({"type":"start"})
func roll(): send_message({"type":"roll"})
func move_piece(piece: int): send_message({"type":"move","piece":piece})
func send_chat(text: String): send_message({"type":"chat","text":text})
