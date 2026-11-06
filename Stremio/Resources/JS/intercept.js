// Injected into every page. Stremio plays through MSE (a blob: <video> source)
// backed by the server's /hlsv2/ ffmpeg transcode, which is slow and stalls.
// We watch fetch/XHR for that transcode request, pull out the RAW file URL it
// wraps (the mediaURL= param), and hand THAT to native VLC — VLC decodes any
// codec directly, skipping the transcode entirely. Plain <video src> (direct,
// non-transcoded content) is caught as a fallback.
