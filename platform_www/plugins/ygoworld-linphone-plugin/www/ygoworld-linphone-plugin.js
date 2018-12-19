cordova.define("ygoworld-linphone-plugin.Linphone", function(require, exports, module) {
module.exports =
{
    initLinphone: function(successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "initLinphone",
            []
        );
    },
    login: function (username, password, domain, transport, proxyServer, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "login",
            [username, password, domain, transport, proxyServer]
        );
    },
    logout: function (successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "logout",
            []
        );
    },
    accept: function (doAccept, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "accept",
            [doAccept]
        );
    },
    listenCallState: function (successCallback, errorCallback) {
        cordova.exec(
                successCallback,
                errorCallback,
                "Linphone",
                "listenCallState",
                []
            );
    },
    call: function (address, displayName, isVideo, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "call",
            [address, displayName, isVideo]
        );
    },
    videocall: function (address, displayName, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "videocall",
            [address, displayName]
        );
    },
    hangup: function (successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "hangup",
            []
        );
    },
    toggleMicro: function (isMute, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "toggleMicro",
            [isMute]
        );
    },
    toggleSpeaker: function (isSpeaker, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "toggleSpeaker",
            [isSpeaker]
        );
    },
    sendDtmf: function (number, successCallback, errorCallback) {
        cordova.exec(
            successCallback,
            errorCallback,
            "Linphone",
            "sendDtmf",
            [number]
        );
    }
};
});
