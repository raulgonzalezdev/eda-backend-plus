// Estado y endpoints
const state = {
  token: localStorage.getItem('jwt') || '',
  userEmail: null,
  stomp: null,
  connected: false,
  subscription: null,
  currentConvId: null,
};

const apiBase = window.location.origin;
const endpoints = {
  login: '/auth/login',
  demoToken: (user='demo-user', scope='alerts.read') => `/auth/token?sub=${encodeURIComponent(user)}&scope=${encodeURIComponent(scope)}`,
  users: '/users',
  chatWs: '/ws',
  chatSend: '/app/chat.sendMessage',
  chatTopic: '/topic/public',
  chatConversations: '/api/chat/conversations',
  chatRestSend: '/api/chat/send',
};

// Utiles
function authHeaders(){ return state.token? { 'Authorization': 'Bearer '+state.token } : {}; }
async function jfetch(path, opts={}){ const res = await fetch(path, { ...opts, headers: { 'Content-Type':'application/json', ...(opts.headers||{}), ...authHeaders() }}); if(!res.ok){ const txt=await res.text(); throw new Error(`HTTP ${res.status}: ${txt}`); } const ct=res.headers.get('content-type')||''; return ct.includes('application/json')? res.json() : res.text(); }
function showToast(message, kind = 'info') { const toastEl = document.getElementById('toast'); if (!toastEl) return; toastEl.className = 'toast ' + kind; toastEl.textContent = message; toastEl.classList.add('show'); setTimeout(() => toastEl.classList.remove('show'), 2200); }
function setToken(t){ state.token = t || ''; localStorage.setItem('jwt', state.token); const st = document.getElementById('authStatus'); st.textContent = state.token? 'autenticado' : 'anónimo'; st.className = 'pill' + (state.token? ' status-ok' : ''); // intentar extraer email del token
  try { const payload = JSON.parse(atob((t||'').split('.')[1]||'')); state.userEmail = payload.sub || null; } catch(_) { state.userEmail = null; } updateNavForAuth(); }
function updateNavForAuth(){ const authed = !!state.token; document.getElementById('navUsers').classList.toggle('hidden', !authed); document.getElementById('navChat').classList.toggle('hidden', !authed); document.getElementById('btnLogout').classList.toggle('hidden', !authed); }
function routeTo(view){ document.querySelectorAll('[data-view]').forEach(v=>v.classList.add('hidden')); document.getElementById(`view-${view}`).classList.remove('hidden'); document.querySelectorAll('nav .nav a').forEach(a=>a.classList.toggle('active', a.getAttribute('href')==='#'+view)); }

// Modal auth
function openAuth(){ document.getElementById('authModal').classList.remove('hidden'); }
function closeAuth(){ document.getElementById('authModal').classList.add('hidden'); }
function switchTab(to){ const isLogin = to==='login'; document.getElementById('formLogin').classList.toggle('hidden', !isLogin); document.getElementById('formRegister').classList.toggle('hidden', isLogin); document.getElementById('tabLogin').classList.toggle('active', isLogin); document.getElementById('tabRegister').classList.toggle('active', !isLogin); }

// Acciones de auth
async function doLogin(){ const email = document.getElementById('loginEmail').value.trim(); const password = document.getElementById('loginPassword').value; try{ const out = await jfetch(endpoints.login, { method:'POST', body: JSON.stringify({ email, password })}); setToken(out.token); showToast('Login correcto','success'); closeAuth(); routeTo('users'); } catch(e){ showToast('Login fallido: '+e.message,'error'); }}
async function getDemoToken(){ try{ const tok = await jfetch(endpoints.demoToken()); setToken(tok); showToast('Token demo generado','success'); closeAuth(); routeTo('users'); } catch(e){ showToast('No se pudo generar token: '+e.message,'error'); }}
async function doRegister(){ const email=document.getElementById('regEmail').value.trim(); const password=document.getElementById('regPassword').value; const firstName=document.getElementById('regFirst').value.trim(); const lastName=document.getElementById('regLast').value.trim(); const role=(document.getElementById('regRole').value.trim()) || 'PATIENT'; try{ await jfetch(endpoints.users, { method:'POST', body: JSON.stringify({ email, password, firstName, lastName, role }) }); showToast('Registro exitoso','success'); // tras registrar, intentamos login directo
    const out = await jfetch(endpoints.login, { method:'POST', body: JSON.stringify({ email, password })}); setToken(out.token); closeAuth(); routeTo('users'); } catch(e){ showToast('Registro fallido: '+e.message,'error'); }}
function logout(){ setToken(''); showToast('Sesión cerrada','info'); routeTo('home'); }

// Usuarios
async function loadUsers(){ try{ const list = await jfetch(endpoints.users); const tbody = document.getElementById('usersTbody'); tbody.innerHTML = ''; list.forEach(u=>{ const tr=document.createElement('tr'); tr.innerHTML = `<td>${u.id||''}</td><td>${u.email||''}</td><td>${u.firstName||''}</td><td>${u.lastName||''}</td><td><span class="pill">${u.role||''}</span></td>`+
      `<td class="row">`+
      `<button class="btn" data-id="${u.id}">Editar</button>`+
      `<button class="btn danger" data-del="${u.id}">Borrar</button>`+
      `</td>`; tbody.appendChild(tr); }); showToast('Usuarios cargados','info'); } catch(e){ showToast('Error al listar: '+e.message,'error'); } }
async function createUser(){ const email=val('userEmail'), firstName=val('userFirst'), lastName=val('userLast'), role=val('userRole'), password=val('userPass'); try{ await jfetch(endpoints.users, { method:'POST', body: JSON.stringify({ email, firstName, lastName, role, password }) }); showToast('Usuario creado','success'); clearUserForm(); loadUsers(); } catch(e){ showToast('Error al crear: '+e.message,'error'); } }
async function updateUser(){ const id=val('userId'); const body = { email: val('userEmail'), firstName: val('userFirst'), lastName: val('userLast'), role: val('userRole'), password: val('userPass') }; try{ await jfetch(endpoints.users+'/'+id, { method:'PUT', body: JSON.stringify(body) }); showToast('Usuario actualizado','success'); clearUserForm(); loadUsers(); } catch(e){ showToast('Error al actualizar: '+e.message,'error'); } }
async function deleteUser(id){ if(!confirm('¿Borrar usuario?')) return; try{ await jfetch(endpoints.users+'/'+id, { method:'DELETE' }); showToast('Usuario borrado','success'); loadUsers(); } catch(e){ showToast('Error al borrar: '+e.message,'error'); } }
function clearUserForm(){ ['userId','userEmail','userFirst','userLast','userRole','userPass'].forEach(id=>set(id,'')); }
function val(id){ return document.getElementById(id).value; }
function set(id,v){ document.getElementById(id).value = v; }

// Chat
function addMessage(m){
  // Filtrar por conversación si está seleccionada
  if (state.currentConvId && Number(m.conversationId) !== Number(state.currentConvId)) {
    return;
  }
  const li=document.createElement('li');
  li.className='msg';
  const meta=`<div class="meta">${m.sender||'anon'} · conv ${m.conversationId||'-'} · ${m.type||'CHAT'}</div>`;
  li.innerHTML = meta + `<div>${String(m.content||'').replace(/[&<>"']/g, c=>({ '&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;','\'':'&#39;' }[c]))}</div>`;
  document.getElementById('chatMessages').prepend(li);
}
function chatConnect(){ if(state.connected){ return showToast('Ya conectado','info'); } const sock = new SockJS(endpoints.chatWs); const client = Stomp.over(sock); client.debug = () => {}; const headers = state.token? { Authorization: 'Bearer '+state.token } : {}; client.connect(headers, () => { state.stomp = client; state.connected = true; document.getElementById('chatConnState').textContent='conectado'; document.getElementById('btnChatConnect').disabled=true; document.getElementById('btnChatDisconnect').disabled=false; document.getElementById('btnChatSend').disabled=false; state.subscription = client.subscribe(endpoints.chatTopic, (frame) => { try{ const msg = JSON.parse(frame.body); addMessage(msg); } catch(e){ addMessage({ sender:'system', content:frame.body, type:'CHAT' }); } }); showToast('Chat conectado','success'); }, (err) => { showToast('Error de conexión: '+err,'error'); }); }
function chatDisconnect(){ try{ state.subscription && state.subscription.unsubscribe(); state.stomp && state.stomp.disconnect(()=>{}); } catch(_){} state.subscription=null; state.stomp=null; state.connected=false; document.getElementById('chatConnState').textContent='desconectado'; document.getElementById('btnChatConnect').disabled=false; document.getElementById('btnChatDisconnect').disabled=true; document.getElementById('btnChatSend').disabled=true; showToast('Chat desconectado','info'); }
function chatSend(){
  if(!state.stomp) return showToast('No conectado','error');
  const content=document.getElementById('chatContent').value||'Hola';
  const sender=document.getElementById('chatSender').value || state.userEmail || 'web';
  const type=document.getElementById('chatType').value||'CHAT';
  let convId = document.getElementById('chatConvId').value? Number(document.getElementById('chatConvId').value) : null;
  if (state.currentConvId && !convId) convId = Number(state.currentConvId);
  const payload={ content, sender, type, conversationId: convId };
  state.stomp.send(endpoints.chatSend, authHeaders(), JSON.stringify(payload));
  showToast('Mensaje enviado','success');
}

// Conversaciones
async function loadConversations(){
  try{
    const list = await jfetch(endpoints.chatConversations);
    const sel = document.getElementById('chatConvSelect');
    sel.innerHTML = '';
    list.forEach(c => {
      const opt = document.createElement('option');
      opt.value = c.id;
      opt.textContent = `Conv ${c.id}`;
      sel.appendChild(opt);
    });
    showToast('Conversaciones cargadas','info');
  } catch(e){ showToast('Error al listar conversaciones: '+e.message,'error'); }
}

function useSelectedConversation(){
  const sel = document.getElementById('chatConvSelect');
  const id = sel.value;
  state.currentConvId = id ? Number(id) : null;
  document.getElementById('chatConvId').value = id || '';
  document.getElementById('currentConvLabel').textContent = id || '-';
  showToast(id ? 'Usando conv '+id : 'Sin conversación seleccionada','info');
}

async function createConversation(){
  try{
    const sender = state.userEmail || 'web';
    const payload = { content: 'Nueva conversación', sender, type: 'JOIN', conversationId: null };
    const res = await jfetch(endpoints.chatRestSend, { method:'POST', body: JSON.stringify(payload) });
    const id = res.conversationId;
    state.currentConvId = id;
    document.getElementById('chatConvId').value = id;
    document.getElementById('currentConvLabel').textContent = id;
    showToast('Conversación creada: '+id, 'success');
    loadConversations();
  } catch(e){ showToast('Error creando conversación: '+e.message,'error'); }
}

// Usuarios para chat
async function loadChatUsers(){
  try{
    const list = await jfetch(endpoints.users);
    const sel = document.getElementById('chatUserSelect');
    sel.innerHTML = '';
    list.forEach(u => {
      const opt = document.createElement('option');
      opt.value = u.id;
      opt.textContent = u.email || `${u.firstName||''} ${u.lastName||''}`.trim();
      sel.appendChild(opt);
    });
    showToast('Usuarios para chat cargados','info');
  } catch(e){ showToast('Error al cargar usuarios: '+e.message,'error'); }
}

async function createConversationWithUser(){
  const sel = document.getElementById('chatUserSelect');
  const userId = sel.value;
  const userLabel = sel.options[sel.selectedIndex]?.textContent || userId || 'usuario';
  try{
    const sender = state.userEmail || 'web';
    const payload = { content: `Conversación con ${userLabel}`, sender, type: 'JOIN', conversationId: null };
    const res = await jfetch(endpoints.chatRestSend, { method:'POST', body: JSON.stringify(payload) });
    const id = res.conversationId;
    state.currentConvId = id;
    document.getElementById('chatConvId').value = id;
    document.getElementById('currentConvLabel').textContent = id;
    showToast('Conversación con usuario creada: '+id, 'success');
    loadConversations();
  } catch(e){ showToast('Error creando conversación con usuario: '+e.message,'error'); }
}

function copyCurrentConvId(){
  const id = document.getElementById('chatConvId').value || document.getElementById('currentConvLabel').textContent || '';
  if(!id){ return showToast('No hay ID de conversación','error'); }
  if(navigator.clipboard && navigator.clipboard.writeText){
    navigator.clipboard.writeText(String(id)).then(()=> showToast('ID copiado al portapapeles','success'))
      .catch(()=> showToast('No se pudo copiar','error'));
  } else {
    // Fallback
    const ta = document.createElement('textarea');
    ta.value = String(id);
    document.body.appendChild(ta);
    ta.select();
    try{ document.execCommand('copy'); showToast('ID copiado','success'); } catch(_) { showToast('No se pudo copiar','error'); }
    document.body.removeChild(ta);
  }
}

// Eventos UI
window.addEventListener('DOMContentLoaded', () => {
  // Inicial
  setToken(state.token);
  const initial = (window.location.hash || '#home').slice(1);
  routeTo(initial);
  updateNavForAuth();

  // Enlaces nav
  document.querySelectorAll('a[data-nav]').forEach(a=>{
    a.addEventListener('click', (e)=>{
      e.preventDefault();
      const view = a.getAttribute('href').slice(1);
      routeTo(view);
      if(view==='users') { loadUsers(); }
      if(view==='chat') { loadConversations(); loadChatUsers(); }
    });
  });

  // Pre-cargar si se abre directamente por hash
  if(initial==='users'){ loadUsers(); }
  if(initial==='chat'){ loadConversations(); loadChatUsers(); }

  // Botones auth
  document.getElementById('btnOpenAuth').addEventListener('click', openAuth);
  document.getElementById('btnOpenAuth2').addEventListener('click', openAuth);
  document.getElementById('btnCloseAuth').addEventListener('click', closeAuth);
  document.getElementById('tabLogin').addEventListener('click', ()=>switchTab('login'));
  document.getElementById('tabRegister').addEventListener('click', ()=>switchTab('register'));
  document.getElementById('btnDoLogin').addEventListener('click', doLogin);
  document.getElementById('btnDemoToken').addEventListener('click', getDemoToken);
  document.getElementById('btnDoRegister').addEventListener('click', doRegister);
  document.getElementById('btnLogout').addEventListener('click', logout);

  // Usuarios
  document.getElementById('btnReloadUsers').addEventListener('click', loadUsers);
  document.getElementById('btnCreateUser').addEventListener('click', createUser);
  document.getElementById('btnUpdateUser').addEventListener('click', updateUser);
  document.getElementById('btnClearUser').addEventListener('click', clearUserForm);
  document.getElementById('usersTbody').addEventListener('click', (e)=>{
    const id = e.target.getAttribute('data-id');
    const delId = e.target.getAttribute('data-del');
    if(id){ // precargar en el formulario
      const row = e.target.closest('tr');
      document.getElementById('userId').value = id;
      document.getElementById('userEmail').value = row.children[1].textContent;
      document.getElementById('userFirst').value = row.children[2].textContent;
      document.getElementById('userLast').value = row.children[3].textContent;
      document.getElementById('userRole').value = row.children[4].textContent.trim();
    } else if(delId){ deleteUser(delId); }
  });

  // Chat
  document.getElementById('btnChatConnect').addEventListener('click', chatConnect);
  document.getElementById('btnChatDisconnect').addEventListener('click', chatDisconnect);
  document.getElementById('btnChatSend').addEventListener('click', chatSend);
  document.getElementById('btnReloadConvs').addEventListener('click', loadConversations);
  document.getElementById('btnUseConv').addEventListener('click', useSelectedConversation);
  document.getElementById('btnNewConv').addEventListener('click', createConversation);
  document.getElementById('btnConvWithUser').addEventListener('click', createConversationWithUser);
  document.getElementById('btnCopyConv').addEventListener('click', copyCurrentConvId);
});