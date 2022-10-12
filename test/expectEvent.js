const assert = require('chai').assert;

const inLogs = async (logs, eventName) => {
    // logs에 있는 event를 가져온다.

    const event = logs.find(e => e.event === eventName);

    assert.exists(event);
}

module.exports = {
    inLogs
}