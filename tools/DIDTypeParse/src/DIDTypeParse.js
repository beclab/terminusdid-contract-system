function parse(typeBytes, fieldNames) {
    if (typeBytes.startsWith("0x")) {
        typeBytes = typeBytes.substring(2);
    }

    if (!_isHex(typeBytes)) {
        throw new Error("input is not a valid hex string");
    }

    let times = -1;
    [l, t] = _parse(0);
    if (l !== typeBytes.length) {
        throw new Error(`input is not a valid typeBytes`);
    }

    return t;

    // input - index: process index of typeBytes
    // return - l: length of parsed bytes, t: type of parsed bytes
    function _parse(index) {
        let b = _readByte(typeBytes, index);
        switch (b) {
            // int
            case "00":
                b = _readByte(typeBytes, index + 2);
                bit = parseInt(b, 16);
                bit = bit * 2 * 2 * 2;
                if (bit < 8 || bit % 8 !== 0 || bit > 256) {
                    throw new Error(`input is not a valid int type`);
                }
                return [index + 4, "int" + bit.toString()];

            // uint
            case "01":
                b = _readByte(typeBytes, index + 2);
                bit = parseInt(b, 16);
                bit = bit * 2 * 2 * 2;
                if (bit < 8 || bit % 8 !== 0 || bit > 256) {
                    throw new Error(`input is not a valid uint type`);
                }
                return [index + 4, "uint" + bit.toString()];

            // bool
            case "02":
                return [index + 2, "bool"];

            // string
            case "03":
                return [index + 2, "string"];

            // array[]
            case "04":
                [l, t] = _parse(index + 2);
                return [l, t + "[]"];

            // array[len]:
            case "05":
                let la = _read2Byte(typeBytes, index + 2);
                la = parseInt(la, 16);
                [l, t] = _parse(index + 6);
                return [l, t + `[${la.toString()}]`];

            // tuple
            case "06":
                let fieldName;
                if (fieldNames) {
                    times++;
                    let fieldNamesIndex = times;
                    if (fieldNamesIndex >= fieldNames.length) {
                        throw new Error("filedNames has insufficient length");
                    }
                    fieldName = fieldNames[fieldNamesIndex];
                }
                let lt = _read2Byte(typeBytes, index + 2);
                lt = parseInt(lt, 16);
                let parsedLen = index + 6;
                let eleT = [];
                for (let k = 0; k < lt; k++) {
                    [l, t] = _parse(parsedLen);
                    parsedLen = l;
                    eleT.push(t);
                }
                if (!fieldNames) {
                    let eleTStr = eleT.join();
                    return [parsedLen, `tuple(${eleTStr})`];
                } else {
                    if (fieldName.length != eleT.length) {
                        throw new Error("parse tuple type with field names error");
                    }

                    let eleTStrWithField = "";
                    for (let k = 0; k < eleT.length; k++) {
                        eleTStrWithField += `${eleT[k]} ${fieldName[k]},`;
                    }
                    eleTStrWithField = eleTStrWithField.substring(0, eleTStrWithField.length - 1);
                    return [parsedLen, `tuple(${eleTStrWithField})`];
                }

            // address
            case "07":
                return [index + 2, "address"];

            // bytesN
            case "08":
                b = _readByte(typeBytes, index + 2);
                bit = parseInt(b, 16);
                if (bit < 1 || bit > 32) {
                    throw new Error(`input is not a valid bytes type`);
                }
                return [index + 4, "bytes" + bit.toString()];

            // bytes
            case "09":
                return [index + 2, "bytes"];

            default:
                throw new Error(`invalid byte ${b} at index ${index}`);
        }
    }
}

function _isHex(hex) {
    return typeof hex === "string"
        && hex.length % 2 === 0
        && !isNaN(Number("0x" + hex))
}

function _readByte(hex, index) {
    return hex.substring(index, index + 2);
}

function _read2Byte(hex, index) {
    return hex.substring(index, index + 4);
}


module.exports = parse;