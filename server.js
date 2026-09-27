import http from 'node:http';
import { WebSocketServer } from 'ws';
import { randomInt } from 'node:crypto';

const PORT = Number(process.env.PORT || 8080);
const MAX_PLAYERS = 4;
const FINISH = 57;
const rooms = new Map();
const server = http.createServer((req, res) => {
  if (req.url === '/health') {
    res.writeHead(200, {'content-type':'application/json'});
    return res.end(JSON.stringify({ok:true, service:'ludo-server', rooms:rooms.size}));
  }
  res.writeHead(200, {'content-type':'text/plain'});
  res.end('Ludo multiplayer server is running');
});
const wss = new WebSocketServer({ server });

const uid = () => randomInt(100000, 999999);
const roomCode = () => {
  const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  let s;
  do { s = ''; for (let i=0;i<6;i++) s += chars[randomInt(chars.length)]; } while (rooms.has(s));
  return s;
};
const send = (ws,msg) => { if (ws.readyState === 1) ws.send(JSON.stringify(msg)); };
const broadcast = (room,msg) => room.players.forEach(p => send(p.ws,msg));
const slotOf = (room,p) => room.players.indexOf(p);
function freshGame(){ return {started:false,turn:0,dice:0,winner:-1,pieces:Array.from({length:MAX_PLAYERS},()=>[-1,-1,-1,-1])}; }
function publicState(room){ return {type:'game_state',room:room.code,players:room.players.map((p,i)=>({slot:i,id:p.id,name:p.name,avatar:p.avatar})),game:room.game}; }
function validMove(room,slot,piece,target){
  const g=room.game;
  if(!g.started||g.winner!==-1||slot!==g.turn||g.dice<1||piece<0||piece>3) return false;
  const old=g.pieces[slot][piece];
  if(old>=FINISH) return false;
  const expected=old===-1?(g.dice===6?1:-999):old+g.dice;
  return target===expected && target<=FINISH;
}
function hasAnyMove(room,slot){
  const g=room.game;
  for(let k=0;k<4;k++){
    const old=g.pieces[slot][k];
    if(old>=FINISH) continue;
    const target=old===-1?(g.dice===6?1:-1):old+g.dice;
    if(target>=1&&target<=FINISH) return true;
  }
  return false;
}
function advanceTurn(room){
  room.game.dice=0;
  if(!room.players.length) return;
  room.game.turn=(room.game.turn+1)%room.players.length;
}
function capture(room,moverSlot,movedPiece){
  const pos=room.game.pieces[moverSlot][movedPiece];
  if(pos<1||pos>52) return;
  for(let s=0;s<room.players.length;s++){
    if(s===moverSlot) continue;
    for(let k=0;k<4;k++){
      if(room.game.pieces[s][k]>=1&&room.game.pieces[s][k]<=52&&room.game.pieces[s][k]===pos) room.game.pieces[s][k]=-1;
    }
  }
}
wss.on('connection',ws=>{
  let player=null;
  ws.on('message',raw=>{
    let m; try{m=JSON.parse(raw.toString());}catch{return send(ws,{type:'error',message:'Invalid JSON'});}
    if(m.type==='create'||m.type==='join'){
      let room;
      if(m.type==='create'){room={code:roomCode(),players:[],game:freshGame()};rooms.set(room.code,room);} else room=rooms.get(String(m.room||'').toUpperCase());
      if(!room) return send(ws,{type:'error',message:'Room not found'});
      if(room.players.length>=MAX_PLAYERS) return send(ws,{type:'error',message:'Room is full'});
      player={id:uid(),name:String(m.name||'Player').slice(0,20),avatar:Number(m.avatar||0),ws};
      room.players.push(player);
      send(ws,{type:m.type==='create'?'room_created':'joined',room:room.code,id:player.id,slot:room.players.length-1});
      broadcast(room,publicState(room)); return;
    }
    if(!player) return send(ws,{type:'error',message:'Create or join a room first'});
    const room=[...rooms.values()].find(r=>r.players.includes(player)); if(!room) return;
    if(m.type==='start'){
      if(room.players.length<2) return send(ws,{type:'error',message:'Need at least 2 players'});
      room.game=freshGame(); room.game.started=true; room.game.turn=0; broadcast(room,publicState(room)); return;
    }
    if(m.type==='roll'){
      const slot=slotOf(room,player),g=room.game;
      if(!g.started||g.winner!==-1||slot!==g.turn||g.dice!==0) return send(ws,{type:'error',message:'Not your turn'});
      g.dice=randomInt(1,7);
      if(!hasAnyMove(room,slot)) advanceTurn(room);
      broadcast(room,publicState(room)); return;
    }
    if(m.type==='move'){
      const slot=slotOf(room,player),piece=Number(m.piece),old=room.game.pieces[slot]?.[piece];
      const target=old===-1?1:old+room.game.dice;
      if(!validMove(room,slot,piece,target)) return send(ws,{type:'error',message:'Invalid move'});
      room.game.pieces[slot][piece]=target; capture(room,slot,piece);
      if(room.game.pieces[slot].every(v=>v===FINISH)) room.game.winner=slot;
      else if(room.game.dice!==6) advanceTurn(room); else room.game.dice=0;
      broadcast(room,publicState(room)); return;
    }
    if(m.type==='chat') broadcast(room,{type:'chat',from:player.name,text:String(m.text||'').slice(0,200)});
  });
  ws.on('close',()=>{
    if(!player) return;
    const room=[...rooms.values()].find(r=>r.players.includes(player)); if(!room) return;
    room.players=room.players.filter(p=>p!==player);
    if(room.players.length===0) return rooms.delete(room.code);
    if(room.game.turn>=room.players.length) room.game.turn=0;
    broadcast(room,publicState(room));
  });
});
server.listen(PORT,'0.0.0.0',()=>console.log(`Ludo server listening on port ${PORT}`));
