module.exports = {
    WORK_MODE: false,
    SERVER_PORT: 1234,
    TEXT_CONTENT: "text/plain",
    JSON_CONTENT: "application/json",
    BLANK_RESPONSE: "OK",

    LogServerListening: function (protocol) {
        console.log("Node." + protocol + " (" + (this.WORK_MODE?"work":"blank") +
            " mode) port " + this.SERVER_PORT + " listening...");
    },

    ProcessJson: function (data) {
        var source = JSON.parse(data);

        var minDate = new Date('9999-12-31T23:59:59.999Z');
        var maxDate = new Date('0000-01-01T00:00:00.000Z');
        source.group.dates.forEach(element => {
            var date = new Date(element);
            if (date < minDate) minDate = date;
            if (date > maxDate) maxDate = date;
        });

        var target = {
            product: source.product,
            requestId: source.requestId,
            client: {
                balance: source.group.balance,
                minDate: minDate,
                maxDate: maxDate
            }
        };    

        return JSON.stringify(target);
    }
};

if (process.argv.length > 2) {
    if (process.argv[2] === '1') {
        module.exports.WORK_MODE = true;
    } 
    if (process.argv[2] === '0') {
        module.exports.WORK_MODE = false;
    } 
}