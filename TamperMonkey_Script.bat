// ==UserScript==
// @name         Weblecture V4
// @namespace    http://tampermonkey.net/
// @version      4
// @description  try to take over the world!
// @author       You
// @match        https://*/*
// @icon         data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==
// @grant        none
// ==/UserScript==

// === BrightSpace DEV TOOLS ===
(function () {
    const found = { video: null, audio: null };

    // ---------- UI ----------
    function showChoiceDialog(callback) {
        const overlay = document.createElement("div");
        overlay.style = `
            position: fixed; inset: 0;
            background: rgba(0,0,0,0.45);
            z-index: 2147483647;
            display: flex; align-items: center; justify-content: center;
        `;
        const card = document.createElement("div");
        card.style = `
            background: #fff; color:#111; width: 480px; max-width: 92vw;
            padding: 18px 20px; border-radius: 14px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);
            font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
        `;
        card.innerHTML = `
            <h2 style="margin:0 0 2px;font-size:20px;">BrightSpace DEV TOOLS</h2>
            <div style="font-size:12px;color:#666;margin-bottom:10px;">Downloader • Cutter • Packager</div>

            <h3 style="margin:8px 0 8px;font-size:16px;">Choose output</h3>
            <div style="display:grid; grid-template-columns:1fr 1fr; gap:10px; margin-bottom:10px;">
                <button id="btn-m4a"  style="padding:10px;border:0;border-radius:8px;background:#4CAF50;color:#fff;cursor:pointer;">🎵 M4A (audio)</button>
                <button id="btn-mp4"  style="padding:10px;border:0;border-radius:8px;background:#2196F3;color:#fff;cursor:pointer;">🎥 MP4 (video+audio)</button>
                <button id="btn-video" style="padding:10px;border:0;border-radius:8px;background:#9C27B0;color:#fff;cursor:pointer;">🎬 Video-only MP4</button>
                <button id="btn-both"  style="padding:10px;border:0;border-radius:8px;background:#FF9800;color:#fff;cursor:pointer;">🎚️ M4A & Video</button>
            </div>

            <label style="display:flex;align-items:center;gap:8px;margin:10px 0;">
                <input id="skip-break" type="checkbox" />
                <span>Skip a break (cut middle segment)</span>
            </label>
            <div id="break-fields" style="display:none; padding:10px; background:#f6f7f9; border-radius:8px;">
                <div style="display:flex; gap:8px; margin-bottom:8px;">
                    <div style="flex:1;">
                        <label style="font-size:12px;color:#555;">Break start (HH:MM:SS)</label>
                        <input id="break-start" type="text" placeholder="00:45:00" value="00:45:00"
                            style="width:100%;padding:8px;border:1px solid #ccc;border-radius:6px;" />
                    </div>
                    <div style="flex:1;">
                        <label style="font-size:12px;color:#555;">Break end (HH:MM:SS)</label>
                        <input id="break-end" type="text" placeholder="00:55:00" value="00:55:00"
                            style="width:100%;padding:8px;border:1px solid #ccc;border-radius:6px;" />
                    </div>
                </div>
                <div style="font-size:12px;color:#666;">
                    Tip: use the player timeline to note exact times.
                </div>
            </div>

            <div style="display:flex;justify-content:flex-end;margin-top:12px;">
                <button id="btn-cancel" style="padding:8px 12px;border:0;border-radius:6px;background:#eee;cursor:pointer;">Cancel</button>
            </div>
        `;
        overlay.appendChild(card);
        document.body.appendChild(overlay);

        const skipBox = card.querySelector("#skip-break");
        const fields = card.querySelector("#break-fields");
        skipBox.addEventListener("change", () => {
            fields.style.display = skipBox.checked ? "block" : "none";
        });

        const close = () => overlay.remove();
        const getTimes = () => ({
            skip: skipBox.checked,
            start: (card.querySelector("#break-start").value || "").trim(),
            end:   (card.querySelector("#break-end").value || "").trim()
        });

        const validateHHMMSS = (s) => /^\d{1,2}:\d{2}:\d{2}$/.test(s);

        function pick(mode) {
            const { skip, start, end } = getTimes();
            if (skip && (!validateHHMMSS(start) || !validateHHMMSS(end))) {
                alert("Please enter HH:MM:SS for break start and end (e.g., 00:45:00 and 00:55:00).");
                return;
            }
            close();
            callback({ mode, skip, start, end });
        }

        card.querySelector("#btn-m4a").onclick  = () => pick("m4a");
        card.querySelector("#btn-mp4").onclick  = () => pick("mp4");
        card.querySelector("#btn-video").onclick= () => pick("video");
        card.querySelector("#btn-both").onclick = () => pick("both");
        card.querySelector("#btn-cancel").onclick = close;
    }

    // ---------- BAT generation ----------
    function batHeader() {
        return [
            "@echo off",
            "title BS DEV TOOLS",
            "chcp 65001 >nul"
        ].join("\r\n") + "\r\n";
    }

    function batFooter() {
        return [
            "echo.",
            "echo ✅ Done. Press any key to close...",
            "pause >nul",
            'del "%~f0"'
        ].join("\r\n") + "\r\n";
    }

    function genM4A(audioUrl, out, skip, start, end) {
        const L = [];
        if (skip) {
            L.push("ffmpeg ^");
            L.push(`-i "${audioUrl}" ^`);
            L.push(`-filter_complex "[0:a]atrim=0:${start},asetpts=N/SR/TB[a0];[0:a]atrim=${end},asetpts=N/SR/TB[a1];[a0][a1]concat=n=2:v=0:a=1[outa]" ^`);
            L.push(`-map "[outa]" -c:a aac -b:a 160k ^`);
            L.push(`"${out}"`);
        } else {
            // Encode to AAC M4A (universal)
            L.push("ffmpeg ^");
            L.push(`-i "${audioUrl}" ^`);
            L.push(`-vn -c:a aac -b:a 160k ^`);
            L.push(`"${out}"`);
        }
        return L.join("\r\n");
    }

    function genVideoOnly(videoUrl, out, skip, start, end) {
        const L = [];
        if (skip) {
            // Accurate middle-cut on video; re-encode H.264
            L.push("ffmpeg ^");
            L.push(`-i "${videoUrl}" ^`);
            L.push(`-filter_complex "[0:v]trim=0:${start},setpts=PTS-STARTPTS[v0];[0:v]trim=${end},setpts=PTS-STARTPTS[v1];[v0][v1]concat=n=2:v=1:a=0[outv]" ^`);
            L.push(`-map "[outv]" -c:v libx264 -preset veryfast -crf 23 ^`);
            L.push(`"${out}"`);
        } else {
            // Stream copy into MP4 container (fast)
            L.push("ffmpeg ^");
            L.push(`-i "${videoUrl}" -an -c copy ^`);
            L.push(`"${out}"`);
        }
        return L.join("\r\n");
    }

    function genMP4(videoUrl, audioUrl, out, skip, start, end) {
        const L = [];
        if (skip) {
            // Accurate mid-cut on both (re-encode)
            L.push("ffmpeg ^");
            L.push(`-i "${videoUrl}" ^`);
            L.push(`-i "${audioUrl}" ^`);
            L.push(`-filter_complex "[0:v]trim=0:${start},setpts=PTS-STARTPTS[v0];` +
                   `[1:a]atrim=0:${start},asetpts=PTS-STARTPTS[a0];` +
                   `[0:v]trim=${end},setpts=PTS-STARTPTS[v1];` +
                   `[1:a]atrim=${end},asetpts=PTS-STARTPTS[a1];` +
                   `[v0][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]" ^`);
            L.push(`-map "[outv]" -map "[outa]" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 160k ^`);
            L.push(`"${out}"`);
        } else {
            // Fast merge (no re-encode)
            L.push("ffmpeg ^");
            L.push(`-i "${videoUrl}" ^`);
            L.push(`-i "${audioUrl}" ^`);
            L.push(`-map 0:v:0 -map 1:a:0 -c copy ^`);
            L.push(`"${out}"`);
        }
        return L.join("\r\n");
    }

    function generateBat({ mode, videoUrl, audioUrl, baseName, skip, start, end }) {
        const lines = [batHeader()];
        if (mode === "m4a") {
            lines.push(genM4A(audioUrl, `${baseName}.m4a`, skip, start, end));
        } else if (mode === "video") {
            lines.push(genVideoOnly(videoUrl, `${baseName}_video.mp4`, skip, start, end));
        } else if (mode === "mp4") {
            lines.push(genMP4(videoUrl, audioUrl, `${baseName}.mp4`, skip, start, end));
        } else if (mode === "both") {
            // Audio m4a + video-only mp4 (two commands)
            lines.push(genM4A(audioUrl, `${baseName}.m4a`, skip, start, end));
            lines.push("");
            lines.push(genVideoOnly(videoUrl, `${baseName}_video.mp4`, skip, start, end));
        }
        lines.push(batFooter());
        return lines.join("\r\n");
    }

    // ---------- Helpers ----------
    function promptBaseName(defaultBase) {
        const name = prompt("📥 Base file name (no extension):", defaultBase);
        return name ? name.trim().replace(/\.(mp4|m4a)$/i, "") : null;
    }

    function downloadBatFile(content, baseName) {
        const blob = new Blob([content], { type: "application/octet-stream" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = `${baseName || "bs-tools"}.bat`;
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    function tryGenerate() {
        const haveAudio = !!found.audio;
        const haveVideo = !!found.video;
        if (!haveAudio && !haveVideo) return;

        showChoiceDialog(({ mode, skip, start, end }) => {
            if ((mode === "mp4" || mode === "video" || mode === "both") && !haveVideo) {
                alert("⚠️ Need a video stream for this option. Waiting until a video playlist is detected…");
                return;
            }
            if ((mode === "mp4" || mode === "m4a" || mode === "both") && !haveAudio) {
                alert("⚠️ Need an audio stream for this option. Waiting until an audio playlist is detected…");
                return;
            }

            const base = promptBaseName("lecture");
            if (!base) return;

            const bat = generateBat({
                mode,
                videoUrl: found.video,
                audioUrl: found.audio,
                baseName: base,
                skip, start, end
            });

            downloadBatFile(bat, base);
            alert(`✅ BS DEV TOOLS: .bat created for "${base}" (${mode.toUpperCase()}${skip ? " • break removed" : ""}).\nDouble-click to run.`);
            found.video = null;
            found.audio = null;
        });
    }

    // ---------- Capture HLS requests ----------
    const origOpen = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url) {
        if (/media_.*\.m3u8/i.test(url) || /video_.*\.m3u8/i.test(url)) {
            found.video = url;
            console.log("🎥 Video URL found:", url);
            tryGenerate();
        } else if (/audio_.*\.m3u8/i.test(url)) {
            found.audio = url;
            console.log("🔊 Audio URL found:", url);
            tryGenerate();
        }
        return origOpen.apply(this, arguments);
    };
})();
