const config = {
	// Listen on the container interface; Podman controls which host interfaces publish the port.
	address: "0.0.0.0",
	port: 8080,
	// Allow remote browser clients. Keep the Podman port bound to 127.0.0.1 unless access is intended.
	ipWhitelist: [],
	modules: [
		{
			module: "clock",
			position: "top_left"
		}
	]
};

if (typeof module !== "undefined") { module.exports = config; }