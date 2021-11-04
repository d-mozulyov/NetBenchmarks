const util = require('util');
const child_process = require('child_process');
const fs = require('fs');        
const {performance} = require('perf_hooks');

async function sleep(ms) {
    return new Promise(resolve => setTimeout(resolve, ms));
}

class Client {

    static classInitializeBlank() {}
    static classInitializeWork() {}    
    static classInitialize(workMode) {
        if (!workMode) {
            return this.classInitializeBlank();
        } else {
            return this.classInitializeWork();
        }          
    }

    constructor (workMode)  {
        this.workMode = workMode;  
    }

    stop() {}

    async checkBlank() {throw new Error("abstract method checkBlank()");}
    async checkWork() {throw new Error("abstract method checkWork()");}
    async check() {
        if (!this.workMode) {
            return await this.checkBlank();
        } else {
            return await this.checkWork();
        }          
    }

    runBlank(callback) {throw new Error("abstract method runBlank()");}
    runWork(callback) {throw new Error("abstract method runWork()");}
    run(callback) {
        if (!this.workMode) {
            return this.runBlank(callback);
        } else {
            return this.runWork(callback);
        }          
    }
}

module.exports = {
    HOST: "127.0.0.1",
    PORT: 1234,
    URL: "http://127.0.0.1:1234",
    TEXT_CONTENT: "text/plain",
    JSON_CONTENT: "application/json",
    BLANK_RESPONSE_DATA: null,
    BLANK_RESPONSE: "OK",
    WORK_REQUEST_DATA: [],
    WORK_REQUEST: "",
    WORK_REQUEST_VALUE: null,
    WORK_RESPONSE_DATA: [],
    WORK_RESPONSE: "",
    WORK_RESPONSE_VALUE: null,
    Client,

    run: async function (clientClass, serverPath, clientCount, workMode) {
        // log
        var serverName = serverPath.replace(".js", "");
        while (true) {
            let index = serverName.indexOf("/");
            if (index < 0)
                break;
            serverName = serverName.substring(index + 1);
        }
        process.stdout.write(util.format("%s %d conn %s... ", serverName, clientCount, workMode?"work":"blank"));

        try {
            // run server
            if (serverPath.indexOf("node ") == 0) {
                var server = child_process.spawn("node", [serverPath.substring("node ".length), workMode?"1":"0"]);
            } else {
                var server = child_process.spawn(serverPath, [workMode?"1":"0"]);
            }    
            await sleep(1000);

            // check client
            clientClass.classInitialize(workMode);
            {
                let client = new clientClass(workMode);
                let error = await client.check();
                client.stop();
                if (error) {
                    throw new Error(error);            
                }    
            }

            // client array
            var clients = new Array(clientCount);
            for (let i = 0; i < clientCount; i++) {
                clients[i] = new clientClass(workMode);
            }
            var topClientIndex = clientCount - 1;     

            // params
            const timeOutInSeconds = 10;
            var terminated = false;
            var requestCount = 0;
            var responseCount = 0;
            setTimeout(function() {
                terminated = true;
            }, 
            timeOutInSeconds * 1000);

            // process loop
            while (!terminated) {
                while (topClientIndex >= 0) {
                    if (terminated) {
                        break;
                    }

                    let client = clients[topClientIndex];
                    topClientIndex--;
                    requestCount++
                    client.run(function(self, done) {
                        topClientIndex++;
                        clients[topClientIndex] = self; 
                        if (!terminated && done) {
                            responseCount++;
                        }    
                    });
                }

                for (let i = 0; i < 10; i++) {
                    if (topClientIndex < 0 && !terminated) {
                        await sleep(0); 
                    } else {
                        break;
                    }
                }

                if (topClientIndex < 0 && !terminated) {
                    await sleep(1);
                }                   
            } 

            // waiting, stopping
            while (topClientIndex != (clientCount - 1)) {
                await sleep(10);
            }
            for (let i = 0; i < clientCount; i++) {
                clients[i].stop();
            }

            // logging
            console.log("requests: %d, responses: %d, throughput: %d/sec", requestCount, responseCount, (responseCount / timeOutInSeconds).toFixed());
        } catch (err) {
            console.log(err);
        } finally {
            if (server) server.kill();
        }
    },

    main: async function(clientClass, serverPaths) {
        console.log(clientClass.name.replace("Client", "Server") + " benchmark running...");

        var clientCounts = [1, 100, 10000];
        var workModes = [false, true];    
        for (var i = 0; i < serverPaths.length; i++) {
            console.log("");
            for (var j = 0; j < clientCounts.length; j++) {
                for (var k = 0; k < workModes.length; k++) {
                    if (global.gc) global.gc();
                    await this.run(clientClass, serverPaths[i], clientCounts[j], workModes[k]);
                }
            }
        }
    }
};

function loadJsonFromFile(fileName) {
    var rawdata = fs.readFileSync(fileName);
    var objdata = JSON.parse(rawdata);
    var strdata = JSON.stringify(objdata); 
    return [rawdata, strdata, objdata];
}

module.exports.BLANK_RESPONSE_DATA = Buffer.from(module.exports.BLANK_RESPONSE, 'utf8');
[module.exports.WORK_REQUEST_DATA, module.exports.WORK_REQUEST, module.exports.WORK_REQUEST_VALUE] = loadJsonFromFile("./source/request.json");
[module.exports.WORK_RESPONSE_DATA, module.exports.WORK_RESPONSE, module.exports.WORK_RESPONSE_VALUE] = loadJsonFromFile("./source/response.json");