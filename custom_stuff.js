document.addEventListener("visibilitychange", () => {
    if (document.hidden) {
        if (window.godotAudioContext) {
            window.godotAudioContext.suspend();
        }
    } else {
        if (window.godotAudioContext) {
            window.godotAudioContext.resume();
        }
    }
});