extends Control

const FINISH := 57
const SERVER_URL := "ws://127.0.0.1:8080"
var online: OnlineClient
var room_code := "----"
var my_slot := -1
var players: Array = []
var game := {"started":false,"turn":0,"dice":0,"winner":-1,"pieces":[]}
var status_label: Label
var room_label: Label
var turn_label: Label
var dice_label: Label
var server_edit: LineEdit
var room_edit: LineEdit
var name_edit: LineEdit
var chat_edit: LineEdit
var chat_log: RichTextLabel
var board: Control
var roll_button: Button
var start_button: Button
var piece_buttons: Array[Button] = []

func _ready():
    online = OnlineClient.new(); add_child(online); online.event_received.connect(_on_server_event)
    _build_ui(); _connect_server(SERVER_URL)

func _build_ui():
    var bg := ColorRect.new(); bg.color = Color("#101827"); bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); add_child(bg)
    var title := Label.new(); title.text = "LUDO ROYAL • ONLINE"; title.position = Vector2(20,18); title.size = Vector2(740,45); title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; title.add_theme_font_size_override("font_size",28); add_child(title)
    status_label = Label.new(); status_label.text = "Connecting..."; status_label.position = Vector2(20,62); status_label.size = Vector2(740,32); status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; add_child(status_label)
    server_edit = LineEdit.new(); server_edit.text = SERVER_URL; server_edit.position = Vector2(25,105); server_edit.size = Vector2(470,42); add_child(server_edit)
    var connect := Button.new(); connect.text = "CONNECT"; connect.position = Vector2(505,105); connect.size = Vector2(120,42); connect.pressed.connect(func(): _connect_server(server_edit.text)); add_child(connect)
    name_edit = LineEdit.new(); name_edit.text = "Player"; name_edit.position = Vector2(25,160); name_edit.size = Vector2(180,42); add_child(name_edit)
    var host := Button.new(); host.text = "CREATE ROOM"; host.position = Vector2(215,160); host.size = Vector2(145,42); host.pressed.connect(_create_room); add_child(host)
    room_edit = LineEdit.new(); room_edit.placeholder_text = "ROOM CODE"; room_edit.position = Vector2(370,160); room_edit.size = Vector2(130,42); add_child(room_edit)
    var join := Button.new(); join.text = "JOIN"; join.position = Vector2(510,160); join.size = Vector2(90,42); join.pressed.connect(_join_room); add_child(join)
    room_label = Label.new(); room_label.text = "ROOM: ----"; room_label.position = Vector2(610,165); room_label.size = Vector2(150,32); add_child(room_label)
    start_button = Button.new(); start_button.text = "START MATCH"; start_button.position = Vector2(25,215); start_button.size = Vector2(180,45); start_button.pressed.connect(func(): online.start_game()); add_child(start_button)
    turn_label = Label.new(); turn_label.position = Vector2(220,220); turn_label.size = Vector2(540,35); turn_label.add_theme_font_size_override("font_size",20); add_child(turn_label)
    board = Control.new(); board.position = Vector2(80,275); board.size = Vector2(600,600); board.draw.connect(_draw_board); add_child(board)
    _make_piece_buttons()
    dice_label = Label.new(); dice_label.text = "🎲 —"; dice_label.position = Vector2(700,300); dice_label.size = Vector2(220,70); dice_label.add_theme_font_size_override("font_size",40); add_child(dice_label)
    roll_button = Button.new(); roll_button.text = "ROLL DICE"; roll_button.position = Vector2(700,375); roll_button.size = Vector2(220,60); roll_button.pressed.connect(func(): online.roll()); add_child(roll_button)
    var chat_panel := PanelContainer.new(); chat_panel.position = Vector2(700,460); chat_panel.size = Vector2(330,330); add_child(chat_panel)
    var cv := VBoxContainer.new(); chat_panel.add_child(cv)
    var ct := Label.new(); ct.text = "💬 ROOM CHAT"; ct.add_theme_font_size_override("font_size",20); cv.add_child(ct)
    chat_log = RichTextLabel.new(); chat_log.custom_minimum_size = Vector2(300,230); cv.add_child(chat_log)
    var row := HBoxContainer.new(); cv.add_child(row); chat_edit = LineEdit.new(); chat_edit.placeholder_text = "Message"; chat_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL; row.add_child(chat_edit)
    var send := Button.new(); send.text = "SEND"; send.pressed.connect(func(): online.send_chat(chat_edit.text); chat_edit.clear()); row.add_child(send)

func _connect_server(url: String):
    status_label.text = "Connecting to server..."
    var err := online.connect_to_server(url)
    if err != OK: status_label.text = "Connection failed: %s" % err

func _create_room():
    online.create_room(name_edit.text)
func _join_room():
    online.join_room(room_edit.text, name_edit.text)

func _on_server_event(m: Dictionary):
    match m.get("type",""):
        "room_created", "joined":
            room_code = str(m.room); my_slot = int(m.slot); room_label.text = "ROOM: %s" % room_code; status_label.text = "Room ready — share the code"
        "game_state":
            room_code = str(m.room); players = m.players; game = m.game; room_label.text = "ROOM: %s" % room_code; status_label.text = "Online • %d player(s)" % players.size(); _refresh_game()
        "chat":
            chat_log.append_text("[b]%s:[/b] %s\n" % [str(m.from), str(m.text)])
        "error": status_label.text = "⚠ " + str(m.message)

func _refresh_game():
    if players.size() > 0 and my_slot < 0:
        for p in players:
            if int(p.slot) == my_slot: break
    var turn_name := "Player %d" % (int(game.turn)+1)
    if int(game.winner) >= 0: turn_label.text = "🏆 Winner: Player %d" % (int(game.winner)+1)
    elif bool(game.started): turn_label.text = "Turn: %s" % turn_name
    else: turn_label.text = "Waiting to start..."
    dice_label.text = "🎲 %s" % ("—" if int(game.dice)==0 else str(game.dice))
    roll_button.disabled = !bool(game.started) or int(game.turn) != my_slot or int(game.dice) != 0 or int(game.winner) >= 0
    for i in range(piece_buttons.size()):
        piece_buttons[i].disabled = !bool(game.started) or int(game.turn) != my_slot or int(game.dice) == 0 or int(game.winner) >= 0
    board.queue_redraw()

func _make_piece_buttons():
    for i in range(4):
        var b := Button.new(); b.text = "G%d" % (i+1); b.position = Vector2(700 + (i%2)*110, 180 + (i/2)*50); b.size = Vector2(95,40); b.pressed.connect(func(): online.move_piece(i)); add_child(b); piece_buttons.append(b)

func _draw_board():
    var r := Rect2(0,0,600,600); board.draw_rect(r,Color("#f4efe6"),true); board.draw_rect(r,Color("#202938"),false,6)
    for i in range(15):
        var x := 30.0 + i*38.0; board.draw_line(Vector2(x,190),Vector2(x,410),Color("#c5bfb4"),1); board.draw_line(Vector2(190,x),Vector2(410,x),Color("#c5bfb4"),1)
    board.draw_rect(Rect2(0,0,190,190),Color("#e94f4f"),true); board.draw_rect(Rect2(410,0,190,190),Color("#4d8fe8"),true); board.draw_rect(Rect2(0,410,190,190),Color("#55b86a"),true); board.draw_rect(Rect2(410,410,190,190),Color("#e9c34a"),true)
    board.draw_string(ThemeDB.fallback_font,Vector2(250,310),"LUDO",HORIZONTAL_ALIGNMENT_LEFT,100,34,Color("#202938"))
