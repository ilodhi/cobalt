import { device } from "$lib/device";
import { defaultLocale } from "$lib/i18n/translations";
import type { CobaltSettings } from "$lib/types/settings";

const defaultSettings: CobaltSettings = {
    schemaVersion: 7,
    advanced: {
        debug: false,
        useWebCodecs: false,
    },
    appearance: {
        theme: "auto",
        language: defaultLocale,
        autoLanguage: true,
        hideRemuxTab: false,
    },
    accessibility: {
        reduceMotion: false,
        reduceTransparency: false,
        disableHaptics: false,
        dontAutoOpenQueue: false,
    },
    save: {
        alwaysProxy: false,
        // disabled by default for self-hosted setups — server tunnel is more reliable
        // than browser-side fetch + ffmpeg over a cloudflare quick tunnel
        localProcessing: "disabled",
        audioBitrate: "128",
        audioFormat: "mp3",
        disableMetadata: false,
        downloadMode: "auto",
        filenameStyle: "basic",
        savingMethod: "download",
        allowH265: false,
        tiktokFullAudio: false,
        convertGif: true,
        videoQuality: "1080",
        subtitleLang: "none",
        youtubeVideoCodec: "h264",
        youtubeVideoContainer: "auto",
        youtubeDubLang: "original",
        youtubeHLS: false,
        youtubeBetterAudio: false,
    },
    processing: {
        customInstanceURL: "",
        customApiKey: "",
        enableCustomInstances: false,
        enableCustomApiKey: false,
        seenCustomWarning: false,
    }
}

export default defaultSettings;
