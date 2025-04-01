// globalRouterService.js
function setupLuaUiRouter() {
  window.bngApi.engineLua("ui_router.setup()");
}

function addRouteToLua(name, path, type) {
  const luaCommand = `ui_router.addRoute({ name = "${name}", path = "${path}", type = "${type}" })`;
  window.bngApi.engineLua(luaCommand);
}

// Function to register Angular routes with Lua UI Router
function registerAngularRoutesToLua() {
  if (!window.angularRouter) {
    console.warn("Angular router (window.angularRouter) not available.");
    return;
  }

  // Retrieve all non-abstract states
  const allStates = window.angularRouter
    .get()
    .filter((state) => !state.abstract);

  // Register each route with Lua UI router
  allStates.forEach((state) => {
    addRouteToLua(state.name, state.url, "angular");
  });

  console.log("Angular routes registered to Lua UI router.");
}

// Function to register Vue routes with Lua UI Router
function registerVueRoutesToLua() {
  if (!window.vueRouter) {
    console.warn("Vue router (window.vueRouter) not available.");
    return;
  }

  // Retrieve all defined routes
  const allRoutes = window.vueRouter.options.routes;

  // Register each route with Lua UI router
  allRoutes.forEach((route) => {
    if (route.children) {
      route.children.forEach((childRoute) => {
        // const path = route.path + "/" + childRoute.path
        const path = ""
        addRouteToLua(childRoute.name, path, "vue");
      });
    } else {
      addRouteToLua(route.name, "", "vue");
    }
  });

  console.log("Vue routes registered to Lua UI router.");
}

// Register Angular and Vue routes with Lua UI Router
function registerAllRoutesToLua() {
  registerAngularRoutesToLua();
  registerVueRoutesToLua();
}

window.onload = function () {
  // Execute the registration immediately
  // setupLuaUiRouter();
  // registerAllRoutesToLua();
  window.bridge.events.on("ui_router_uiReady", () => {
    setupLuaUiRouter();
    registerAllRoutesToLua();
  });
};
