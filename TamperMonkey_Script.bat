// ==UserScript==
// @name         Weblectures Download
// @namespace    https://weblectures.ru.nl/
// @version      3
// @description  Download Lectures - Choose M4A/MP4
// @match        https://weblectures.ru.nl/*
// @grant        none
// ==/UserScript==

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
            background: #fff; color:#111; width: 420px; max-width: 92vw;
            padding: 18px 20px; border-radius: 14px; box-shadow: 0 10px 30px rgba(0,0,0,0.35);
            font-family: system-ui, -apple-system, Segoe UI, Roboto, Arial, sans-serif;
        `;
        card.innerHTML = `
            <h3 style="margin:0 0 8px;font-size:18px;">Export options</h3>
            <div style="display:flex; gap:10px; margin-bottom:10px;">
                <button id="btn-m4a" style="flex:1;padding:10px;border:0;border-radius:8px;background:#4CAF50;color:#fff;cursor:pointer;">🎵 M4A (audio)</button>
                <button id="btn-mp4" style="flex:1;padding:10px;border:0;border-radius:8px;background:#2196F3;color:#fff;cursor:pointer;">🎥 MP4 (video)</button>
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
                    Tip: use the player’s timeline to note exact times.
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
            end: (card.querySelector("#break-end").value || "").trim()
        });

        const validateHHMMSS = (s) => /^\d{1,2}:\d{2}:\d{2}$/.test(s);

        function pick(mode) {
            const { skip, start, end } = getTimes();
            if (skip) {
                if (!validateHHMMSS(start) || !validateHHMMSS(end)) {
                    alert("Please enter HH:MM:SS for break start and end (e.g., 00:45:00 and 00:55:00).");
                    return;
                }
            }
            close();
            callback({ mode, skip, start, end });
        }

        card.querySelector("#btn-m4a").onclick = () => pick("m4a");
        card.querySelector("#btn-mp4").onclick = () => pick("mp4");
        card.querySelector("#btn-cancel").onclick = close;
    }

    // ---------- BAT generation ----------
    function generateBatCommand({ mode, videoUrl, audioUrl, outputPath, skip, start, end }) {
        const lines = [];
        lines.push("@echo off");

        if (mode === "m4a") {
            if (skip) {
                // Accurate middle-cut on audio, then re-encode AAC
                lines.push("ffmpeg ^");
                lines.push(`-i "${audioUrl}" ^`);
                lines.push(`-filter_complex "[0:a]atrim=0:${start},asetpts=N/SR/TB[a0];[0:a]atrim=${end},asetpts=N/SR/TB[a1];[a0][a1]concat=n=2:v=0:a=1[outa]" ^`);
                lines.push(`-map "[outa]" -c:a aac -b:a 160k ^`);
                lines.push(`"${outputPath}"`);
            } else {
                // Straight copy or encode to AAC M4A
                lines.push("ffmpeg ^");
                lines.push(`-i "${audioUrl}" ^`);
                lines.push(`-vn -c:a aac -b:a 160k ^`);
                lines.push(`"${outputPath}"`);
            }
        } else { // MP4
            if (skip) {
                // Accurate middle-cut (re-encode)
                lines.push("ffmpeg ^");
                lines.push(`-i "${videoUrl}" ^`);
                lines.push(`-i "${audioUrl}" ^`);
                lines.push(`-filter_complex ` +
                    `"[0:v]trim=0:${start},setpts=PTS-STARTPTS[v0];` +
                    `[1:a]atrim=0:${start},asetpts=PTS-STARTPTS[a0];` +
                    `[0:v]trim=${end},setpts=PTS-STARTPTS[v1];` +
                    `[1:a]atrim=${end},asetpts=PTS-STARTPTS[a1];` +
                    `[v0][a0][v1][a1]concat=n=2:v=1:a=1[outv][outa]" ^`);
                lines.push(`-map "[outv]" -map "[outa]" -c:v libx264 -preset veryfast -crf 23 -c:a aac -b:a 160k ^`);
                lines.push(`"${outputPath}"`);
            } else {
                // Fast merge (stream copy)
                lines.push("ffmpeg ^");
                lines.push(`-i "${videoUrl}" ^`);
                lines.push(`-i "${audioUrl}" ^`);
                lines.push(`-map 0:v:0 -map 1:a:0 -c copy ^`);
                lines.push(`"${outputPath}"`);
            }
        }

        lines.push("echo.");
        lines.push("echo ✅ Done. Press any key to close...");
        lines.push("pause >nul");
        lines.push('del "%~f0"');
        return lines.join("\r\n") + "\r\n";
    }

    // ---------- Helpers ----------
    function promptForSaveAs(defaultName) {
        const name = prompt("📥 File name (with extension):", defaultName);
        return name ? name.trim() : null;
    }

    function downloadBatFile(content, outputName) {
        const blob = new Blob([content], { type: "application/octet-stream" });
        const a = document.createElement("a");
        a.href = URL.createObjectURL(blob);
        a.download = outputName.replace(/\.(mp4|m4a)$/i, "") + ".bat";
        document.body.appendChild(a);
        a.click();
        document.body.removeChild(a);
    }

    function tryGenerate() {
        const haveAudio = !!found.audio;
        const haveVideo = !!found.video;

        if (!haveAudio && !haveVideo) return;

        showChoiceDialog(({ mode, skip, start, end }) => {
            if (mode === "mp4" && !(haveAudio && haveVideo)) {
                alert("⚠️ Need both video and audio to build MP4. Waiting until both streams are detected…");
                return;
            }

            const defaultName = mode === "m4a" ? "lecture_audio.m4a" : "lecture_video.mp4";
            const saveName = promptForSaveAs(defaultName);
            if (!saveName) return;

            const bat = generateBatCommand({
                mode,
                videoUrl: found.video,
                audioUrl: found.audio,
                outputPath: saveName,
                skip,
                start,
                end
            });

            downloadBatFile(bat, saveName);
            alert(`✅ .bat file created (${mode.toUpperCase()}${skip ? " w/ break removed" : ""}).\nDouble-click to run.`);
            found.video = null;
            found.audio = null;
        });
    }

    // ---------- Capture video/audio requests ----------
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
