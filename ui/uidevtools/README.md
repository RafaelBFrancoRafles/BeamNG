# UI Dev Tools
Application that helps UI debug issues. Only feature for now is it records
the game's lua messages received by UI and some helpful features.

- view formatted json data
- copy json data to clipboard
- save data as json file

# Integrating in game
Add both script files to `ui\entrypoints\main\index.html`

- `<script src="http://localhost:8085"></script>` - to setup the required configuration like the websocket host and port
- `<script src="http://localhost:8085/devtools.js"></script>` - to add global
function needed to listen to the game hooks

# Accessing the App
- Open `http://localhost:8086` to view the devtools dashboard