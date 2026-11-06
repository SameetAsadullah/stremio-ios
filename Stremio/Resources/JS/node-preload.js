const net=require('net'); const listen=net.Server.prototype.listen;
const ours=p=>(p=Number(p))>=11470&&p<=11474;
net.Server.prototype.listen=function(...a){
  if(a[0]&&typeof a[0]==='object'&&ours(a[0].port)&&!a[0].host) a[0]=Object.assign({},a[0],{host:'127.0.0.1'});
  else if(ours(a[0])&&typeof a[1]!=='string') a.splice(1,0,'127.0.0.1');
  return listen.apply(this,a);
};
const fs=require('fs'); const L=process.env.STREMIO_LOG_PATH;
const w=(t,a)=>{try{fs.appendFileSync(L,new Date().toISOString().slice(11,19)+' '+t+' '+Array.prototype.map.call(a,String).join(' ')+'\n')}catch(e){}};
console.log=function(){w('[log]',arguments)}; console.error=function(){w('[err]',arguments)}; console.warn=function(){w('[warn]',arguments)};
process.on('uncaughtException',e=>w('[uncaught]',[e&&e.stack||e])); process.on('unhandledRejection',e=>w('[rej]',[e&&e.stack||e]));
w('[boot]',['preload active, node '+process.version]);
