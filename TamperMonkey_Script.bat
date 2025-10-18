// ==UserScript==
// @name         Weblectures - Generate ffmpeg BAT (Self-Deleting)
// @namespace    https://weblectures.ru.nl/
// @version      1.2
// @description  Create ffmpeg .bat to download and merge video/audio, then self-delete
// @match        https://weblectures.ru.nl/*
// @grant        none
// ==/UserScript==

(function () {
    const found = { video: null, audio: null };

    function generateBatCommand(videoUrl, audioUrl, outputPath) {
        return `@echo off\r\n` +
            `ffmpeg ^\r\n` +
            `-i "${videoUrl}" ^\r\n` +
            `-i "${audioUrl}" ^\r\n` +
            `-map 0:v:0 -map 1:a:0 -c copy "${outputPath}"\r\n` +
            `echo.\r\n` +
            `echo ✅ Download complete. Press any key to close...\r\n` +
            `pause >nul\r\n` +
            `del "%~f0"\r\n`;
    }

    function promptForSaveAs(defaultName = "video.mp4") {
        const outputPath = prompt("📥 Enter output file name (e.g., lecture1.mp4):", defaultName);
        return outputPath ? outputPath : null;
    }

    function downloadBatFile(commandContent, outputName) {
        const blob = new Blob([commandContent], { type: "application/octet-stream" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = outputName.endsWith(".bat") ? outputName : outputName.replace(/\.mp4$/i, ".bat");
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    function tryGenerate() {
        if (found.video && found.audio) {
            const saveName = promptForSaveAs("downloaded_video.mp4");
            if (!saveName) return;

            const command = generateBatCommand(found.video, found.audio, saveName);
            downloadBatFile(command, saveName);
            alert("✅ .bat file generated and downloaded.\nDouble-click it to download the video.\nIt will delete itself after finishing.");
            found.video = found.audio = null; // Reset
        }
    }

    const origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
        if (/media_.*\.m3u8/.test(url)) {
            found.video = url;
            console.log("🎥 Video URL found:", url);
            tryGenerate();
        } else if (/audio_.*\.m3u8/.test(url)) {
            found.audio = url;
            console.log("🔊 Audio URL found:", url);
            tryGenerate();
        }
        return origOpen.apply(this, arguments);
    };
})();
