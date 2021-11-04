const benchmarks = require('./benchmarks.js')
const http = require('http');

var options = {
    host: benchmarks.HOST,
    port: benchmarks.PORT,
    path: "/",
    method: "GET"
}

class HttpClient extends benchmarks.Client {

    static classInitializeBlank() {
        delete options.headers;
    }
    static classInitializeWork() {
        options.headers = {
            'Content-Type': benchmarks.JSON_CONTENT,
            'Content-Length': benchmarks.WORK_REQUEST_DATA.byteLength
        };
    } 

    constructor (workMode) {
        super(workMode);
    }

    async checkBlank() {
        return new Promise((resolve, reject) => {
            var req = http.request(options, (res) => {
                var contentType = res.headers["content-type"];
                if (res.statusCode !== 200) {
                    res.resume();
                    resolve("Invalid code: " + res.statusCode);
                    return;
                } else if (contentType.indexOf(benchmarks.TEXT_CONTENT) < 0) {
                    res.resume();
                    resolve("Invalid content type: " + contentType);
                    return;
                }

                res.setEncoding('utf8');
                var data = "";
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    try {
                        if (data !== benchmarks.BLANK_RESPONSE) {
                            throw new Error("Invalid response: " + data);
                        }
                    } catch (e) {
                        resolve(e.message);
                        return;
                    }   

                    resolve(null);
                    return;
                });
            });
              
            req.on('error', (e) => {
                resolve(e.message);
                return;
            });
              
            req.end();
        });
    }

    async checkWork() {
        return new Promise((resolve, reject) => {
            var req = http.request(options, (res) => {
                var contentType = res.headers["content-type"];
                if (res.statusCode !== 200) {
                    res.resume();
                    resolve("Invalid code: " + res.statusCode);
                    return;
                } else if (contentType.indexOf(benchmarks.JSON_CONTENT) < 0) {
                    res.resume();
                    resolve("Invalid content type: " + contentType);
                    return;
                }

                res.setEncoding('utf8');
                var data = "";
                res.on('data', (chunk) => { data += chunk; });
                res.on('end', () => {
                    try {              
                        var obj = JSON.parse(data);
                        var str = JSON.stringify(obj);          
                        if (str !== benchmarks.WORK_RESPONSE) {
                            throw new Error("Invalid response: " + data);
                        }
                    } catch (e) {
                        resolve(e.message);
                        return;
                    }   

                    resolve(null);
                    return;
                });
            });
              
            req.on('error', (e) => {
                resolve(e.message);
                return;
            });
              
            req.write(benchmarks.WORK_REQUEST_DATA);
            req.end();
        });
    }

    run(callback) {
        var req = http.request(options, (res) => {
            if (res.statusCode !== 200) {
                res.resume();
                callback(this, false);
                return;
            }
            res.setEncoding('utf8');
            var data = "";
            res.on('data', (chunk) => { data += chunk; });
            res.on('end', () => {
                callback(this, true);
                return;
            });
        });
          
        req.on('error', (e) => {
            callback(this, false);
            return;
        });
          
        if (this.workMode) {
            req.write(benchmarks.WORK_REQUEST_DATA);
        }
        req.end();
    }
}


benchmarks.main(HttpClient, [
    "bin/HTTP/Indy.HTTP",
    "bin/HTTP/IndyPool.HTTP",
    "bin/HTTP/RealThinClient.HTTP",
    "bin/HTTP/Synopse.HTTP",
    "bin/HTTP/TMSSparkle.HTTP",
    "node source/Node.js/Node.HTTP.js",
    "bin/HTTP/Golang.HTTP"
]);
