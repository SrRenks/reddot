import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pam

/**
 * Lock authentication. Password and fingerprint are separate PAM contexts.
 * The fingerprint context starts only after Enter on an empty field, so the
 * password never enters the fingerprint prompt and the two paths cannot loop.
 */
Item {
    id: auth

    property string user: ""

    readonly property bool passwordActive: passwordPam.active
    readonly property bool fingerprintActive: fingerPam.active
    readonly property bool authenticating: passwordActive
    readonly property bool fingerprintAvailable: fingerProbe.available
    readonly property string promptText: passwordPrompt.length > 0
        ? passwordPrompt : (fingerPrompt.length > 0 ? fingerPrompt : "")

    property string pendingPassword: ""
    property string passwordPrompt: ""
    property string fingerPrompt: ""
    property string lastError: ""
    property string fingerprintError: ""
    property bool finishing: false

    signal failed
    signal succeeded

    function cleanMessage(message, fallback) {
        var text = String(message || "").trim();
        if (text.length === 0 || /^[0-9]+$/.test(text))
            return fallback;
        return text;
    }

    function submit(password) {
        if (passwordPam.active || password.length === 0)
            return;
        if (fingerPam.active)
            auth.cancelFingerprint();
        auth.lastError = "";
        auth.passwordPrompt = "";
        auth.pendingPassword = password;
        passwordPam.start();
    }

    function startFingerprint() {
        if (!auth.fingerprintAvailable || fingerPam.active || passwordPam.active)
            return;
        auth.fingerprintError = "";
        auth.fingerPrompt = "";
        fingerPam.start();
    }

    function cancelFingerprint() {
        if (fingerPam.active)
            fingerPam.abort();
        auth.fingerPrompt = "";
    }

    function complete(result) {
        if (auth.finishing)
            return;
        auth.pendingPassword = "";
        if (result === PamResult.Success) {
            auth.finishing = true;
            fingerPam.abort();
            passwordPam.abort();
            auth.succeeded();
            return;
        }
        auth.failed();
    }

    function reset() {
        auth.finishing = false;
        auth.pendingPassword = "";
        auth.passwordPrompt = "";
        auth.fingerPrompt = "";
        auth.lastError = "";
        auth.fingerprintError = "";
        if (fingerPam.active)
            fingerPam.abort();
        if (passwordPam.active)
            passwordPam.abort();
    }

    Process {
        id: fingerProbe
        property bool available: false
        command: ["sh", "-c", "command -v fprintd-list >/dev/null 2>&1 && fprintd-list \"$(id -un)\" >/dev/null 2>&1"]
        onExited: code => fingerProbe.available = code === 0
    }

    Component.onCompleted: fingerProbe.running = true

    PamContext {
        id: passwordPam

        config: "reddot-password"
        configDirectory: Quickshell.shellDir + "/pam.d"
        user: auth.user

        onPamMessage: {
            if (message.length > 0) {
                auth.passwordPrompt = message;
                if (messageIsError)
                    auth.lastError = auth.cleanMessage(message, "wrong password");
            }
            if (responseRequired && auth.pendingPassword.length > 0) {
                let password = auth.pendingPassword;
                auth.pendingPassword = "";
                passwordPam.respond(password);
            }
        }

        onCompleted: result => {
            if (result !== PamResult.Success && auth.lastError.length === 0)
                auth.lastError = "wrong password";
            auth.complete(result);
        }

        onError: error => {
            auth.lastError = "authentication error";
            auth.complete(PamResult.Error);
        }
    }

    PamContext {
        id: fingerPam

        config: "reddot-fprint"
        configDirectory: Quickshell.shellDir + "/pam.d"
        user: auth.user

        onPamMessage: {
            if (message.length > 0)
                auth.fingerPrompt = message;
            if (messageIsError && message.length > 0)
                auth.fingerprintError = auth.cleanMessage(message, "fingerprint not recognized");
        }

        onCompleted: result => {
            auth.fingerPrompt = "";
            if (result === PamResult.Success) {
                auth.fingerprintError = "";
                auth.complete(result);
                return;
            }
            auth.fingerprintError = "fingerprint not recognized";
        }

        onError: error => {
            auth.fingerPrompt = "";
            auth.fingerprintError = "fingerprint unavailable";
        }
    }
}
