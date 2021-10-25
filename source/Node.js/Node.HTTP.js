
const servers = require('./Servers.js')
const http = require('http'); 

servers.LogServerListening("HTTP");

if (!servers.WORK_MODE) {
    // blank mode
    http.createServer((req, res) => {
        res.writeHead(200, { 'Content-Type': servers.TEXT_CONTENT });
        res.end(servers.BLANK_RESPONSE);
    }).listen(servers.SERVER_PORT, 'localhost');
} 
else {
    // work mode
    http.createServer((req, res) => {
        let data = '';
        req.on('data', chunk => {
            data += chunk;
        })
        req.on('end', () => {
            var str = servers.ProcessJson(data);
            res.writeHead(200, { 'Content-Type': servers.JSON_CONTENT });
            res.end(str);
        })       
    }).listen(servers.SERVER_PORT, 'localhost');
}


