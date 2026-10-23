%% FS_Akku_Thermik.m  --  Pack konfigurieren, Simscape generieren, simulieren, Temperaturen animieren
clear; clc; close all;

%% KONFIGURATION
cfg.name            = "2024_144s1p_604V_Akkumulator_modell";

% Zelle (Melasta SLPB9675175)
cfg.cell.width      = 0.074;     % m
cfg.cell.length     = 0.175;     % m
cfg.cell.thickness  = 0.0093;    % m
cfg.cell.tabWidth   = 0.025;     % m
cfg.cell.mass       = 0.266;     % kg
cfg.cell.capacity   = 14;        % Ah
cfg.cell.V          = 3.7;       % V

% Cfg Stack Mechanisch
cfg.Zellen_Mechanisch_in_reihe_pro_Stack = 1;
cfg.Zellen_Mechanisch_in_reihe_por_stack = 1;
cfg.Stacks_in_x_richtung = 1;
cfg.Stacks_in_y_richtung = 1;

% Topologie
cfg.nParallel       = 1;         % Zellen parallel je Serienglied
cfg.cellsPerStack   = 12;        % Zellen in Serie je Stack
cfg.nStacks         = 12;        % Stacks im Pack (alle in Serie)
cfg.rows            = 3;         % Layout 3 x 4 (nur Anordnung)
cfg.stackAxis       = "Y";       % StackingAxis im Modul ("X" oder "Y")
cfg.layoutAxis      = "Y";       % StackingAxis der Modulanordnung
cfg.stackGap        = 0.005;     % m, Abstand Stacks

% Thermik
cfg.thermal.ambientPath = [];    % z.B. "SetTemperature" (Wert per doc batteryModule pruefen), [] = Default

% Simulation
cfg.sim.I_dis       = 28;        % A, Entladestrom (konstant)
cfg.sim.tEnd        = 600;       % s
cfg.sim.Tamb        = 25;        % degC (nur Anzeige/Plausibilitaet)
cfg.sim.doAnimation = true;

%% 1. TOPOLOGIE SICHERSTELLEN
nSeries = cfg.cellsPerStack * cfg.nStacks;
nCols = cfg.nStacks / cfg.rows;

%% Lambo macht weiter

% Define Cell Geomtrie
bc_geo                = batteryPouchGeometry();
bc_geo.Length         = cfg.cell.length;
bc_geo.Thickness      = cfg.cell.thickness;
bc_geo.TabLocation    = "Standard";
bc_geo.TabWidth       = cfg.cell.tabWidth;
bc_geo.TabHeight      = cfg.cell.tabWidth;
bc_geo.Height         = 0.28;

% Define Cell Eletric data
bc                  = batteryCell(bc_geo);
bc.Mass             = cfg.cell.mass;
bc.Capacity         = cfg.cell.capacity;
bc.Energy           = cfg.cell.V * cfg.cell.capacity;
bc.CellModelOptions.BlockParameters.ThermalModel = "LumpedThermalMass";

% f = figure("Color","k","Name","Pack");
% batteryChart(f, bc)
% drawnow;

% Define the Parralel Assemlby
pa = batteryParallelAssembly(bc, cfg.nParallel);

% Define the Parralel Assembly
module = batteryModule(pa)

keyboard
%% 2. BATTERY-BUILDER-OBJEKTE
geo = batteryPouchGeometry(simscape.Value(cfg.cell.width,"m"), simscape.Value(cfg.cell.length,"m"));
geo.Thickness   = simscape.Value(cfg.cell.thickness,"m");
geo.TabWidth    = simscape.Value(cfg.cell.tabWidth,"m");
geo.TabLocation = "Standard";

bc = batteryCell(geo);
bc.Mass     = simscape.Value(cfg.cell.mass,"kg");
bc.Capacity = simscape.Value(cfg.cell.capacity,"A*hr");
bc.CellModelOptions.BlockParameters.ThermalModel = "LumpedThermalMass";

pa = batteryParallelAssembly(bc, cfg.nParallel);

modArgs = {"ModelResolution","Lumped","StackingAxis",cfg.stackAxis};
if ~isempty(cfg.thermal.ambientPath)
    modArgs = [modArgs, {"AmbientThermalPath", cfg.thermal.ambientPath}];
end
stack = batteryModule(pa, cfg.cellsPerStack, modArgs{:});

gapV = simscape.Value(cfg.stackGap,"m");
modAsm = batteryModuleAssembly(repmat(stack,1,nCols), "NumLevels",cfg.rows, "StackingAxis",cfg.layoutAxis, "InterModuleGap",gapV);
pack = batteryPack(modAsm);

f = figure("Color","k","Name","Pack");
ch = batteryChart(f, pack);          %#ok<NASGU>
drawnow;

% Restskript (Simscape modell und plots)
% %% 3. SIMSCAPE-BIBLIOTHEK GENERIEREN
% if bdIsLoaded(cfg.name), close_system(cfg.name, 0); end
% buildBattery(pack, LibraryName = cfg.name, Verbose = "off");
% load_system(cfg.name);
% 
% % Pack-Block = Subsystem mit Ports
% allB = find_system(cfg.name, "SearchDepth", 1, "Type", "Block");
% allB = allB(~strcmp(allB, cfg.name));
% packSrc = "";
% for k = 1:numel(allB)
%     ph = get_param(allB{k}, "PortHandles");
%     if numel(ph.LConn) >= 1 && numel(ph.RConn) >= 1
%         packSrc = string(allB{k}); break
%     end
% end
% assert(packSrc ~= "", "Kein Block mit Ports in %s gefunden.", cfg.name);
% fprintf("Pack-Block: %s\n", packSrc);
% 
% %% 4. SIMULINK-TESTMODELL
% mdl = cfg.name + "_Test";
% if bdIsLoaded(mdl), close_system(mdl, 0); end
% new_system(mdl); open_system(mdl);
% set_param(mdl, "StopTime", string(cfg.sim.tEnd), "Solver", "ode23t", ...
%     "SimscapeLogType", "all", "SimscapeLogName", "simlog");
% 
% add_block(packSrc, mdl+"/Pack", "Position", [300 100 420 220]);
% add_block("nesl_utility/Solver Configuration", mdl+"/SolverCfg", "Position", [100 300 160 330]);
% add_block("fl_lib/Electrical/Electrical Elements/Electrical Reference", mdl+"/GND", "Position", [300 330 330 360]);
% add_block("fl_lib/Electrical/Electrical Sources/Controlled Current Source", mdl+"/Iload", "Position", [520 100 580 160]);
% add_block("simulink/Sources/Constant", mdl+"/Istrom", "Value", string(cfg.sim.I_dis), "Position", [380 20 430 50]);
% add_block("nesl_utility/Simulink-PS Converter", mdl+"/S2PS", "Position", [460 20 500 50]);
% add_block("fl_lib/Electrical/Electrical Sensors/Voltage Sensor", mdl+"/Usens", "Position", [520 200 580 260]);
% add_block("nesl_utility/PS-Simulink Converter", mdl+"/PS2S_U", "Position", [620 215 660 245]);
% add_block("simulink/Sinks/To Workspace", mdl+"/U_out", "VariableName", "Upack", ...
%     "SaveFormat", "Timeseries", "Position", [700 215 760 245]);
% 
% % Ports nach Lage bestimmen (+ oben, - unten rechts, Signal unten links)
% iP = portByPos(mdl+"/Iload","top");   iN = portByPos(mdl+"/Iload","bottomRight"); iS = portByPos(mdl+"/Iload","bottomLeft");
% uP = portByPos(mdl+"/Usens","top");   uN = portByPos(mdl+"/Usens","bottomRight"); uV = portByPos(mdl+"/Usens","bottomLeft");
% 
% add_line(mdl, "Istrom/1",    "S2PS/1");
% add_line(mdl, "S2PS/RConn1", "Iload/"+iS);
% add_line(mdl, "Pack/LConn1", "Iload/"+iP);
% add_line(mdl, "Pack/RConn1", "Iload/"+iN);
% add_line(mdl, "Pack/LConn1", "Usens/"+uP);
% add_line(mdl, "Pack/RConn1", "Usens/"+uN);
% add_line(mdl, "Pack/RConn1", "GND/LConn1");
% add_line(mdl, "SolverCfg/RConn1", "Pack/RConn1");
% add_line(mdl, "Usens/"+uV,   "PS2S_U/LConn1");
% add_line(mdl, "PS2S_U/1",    "U_out/1");
% 
% %% 5. SIMULATION
% out = sim(mdl);
% U   = out.Upack;
% fprintf("Pack-Spannung: Start %.1f V, Ende %.1f V (erwartet Start ca. %.0f V)\n", ...
%     U.Data(1), U.Data(end), nSeries*cfg.cell.Vnom);
% if abs(U.Data(1)) < 0.5*nSeries*cfg.cell.Vnom
%     warning("Startspannung passt nicht zu 144s. Topologie im Modell pruefen.");
% end
% 
% %% 6. TEMPERATUREN AUSLESEN
% [tT, T, tNames] = collectTemps(out.simlog);
% if isempty(T)
%     disp("Keine Temperaturknoten gefunden. Geloggte Knoten:");
%     printTree(out.simlog, "");
%     error("Poste die obige Knotenliste, dann passe ich collectTemps an.");
% end
% nT = size(T,2);
% fprintf("%d Temperaturknoten gefunden.\n", nT);
% if nT == nSeries*cfg.nParallel                       % Zellaufloesung -> je Stack mitteln
%     T = squeeze(mean(reshape(T, size(T,1), cfg.cellsPerStack, cfg.nStacks), 2));
% elseif nT ~= cfg.nStacks
%     warning("%d Knoten, erwartet %d (Stacks). Nehme die ersten %d.", nT, cfg.nStacks, cfg.nStacks);
%     T = T(:, 1:min(nT,cfg.nStacks));
% end
% 
% %% 7. PLOTS
% fig1 = figure("Color","k","Name","Temperaturverlauf");
% ax1 = axes(fig1,"Color","k","XColor","w","YColor","w","GridColor","w");
% plot(ax1, tT/60, T, "LineWidth",1.2); grid(ax1,"on");
% xlabel(ax1,"t in min"); ylabel(ax1,"T in degC");
% title(ax1,"Stack-Temperaturen","Color","w");
% 
% if cfg.sim.doAnimation
%     animateStacks(tT, T, cfg, nCols);
% end

%% LOKALE FUNKTIONEN
% function name = portByPos(blk, where)
%     pc  = get_param(blk, "PortConnectivity");
%     pos = vertcat(pc.Position);
%     typ = string({pc.Type}).';
%     yMid = mean([min(pos(:,2)) max(pos(:,2))]);
%     switch where
%         case "top"
%             [~,i] = min(pos(:,2));
%         case "bottomLeft"
%             idx = find(pos(:,2) > yMid); [~,j] = min(pos(idx,1)); i = idx(j);
%         case "bottomRight"
%             idx = find(pos(:,2) > yMid); [~,j] = max(pos(idx,1)); i = idx(j);
%     end
%     name = typ(i);
%     fprintf("%s %-12s -> %s\n", blk, where, name);
% end
% 
% function [t, T, names] = collectTemps(node)
%     t = []; T = []; names = strings(0);
%     [t, T, names] = walk(node, "", t, T, names);
% end
% 
% function [t, T, names] = walk(node, path, t, T, names)
%     ids = string(node.children());
%     for k = 1:numel(ids)
%         id = ids(k);  child = node.(id);
%         isLeaf = true;
%         try, s = child.series; catch, isLeaf = false; end
%         if isLeaf
%             if id == "T"
%                 try
%                     v = s.values("degC");
%                 catch
%                     v = s.values("K") - 273.15;
%                 end
%                 if isempty(t), t = s.time; end
%                 if numel(s.time) == numel(t)
%                     T(:,end+1) = v(:); names(end+1) = path + "/" + id; %#ok<AGROW>
%                 end
%             end
%         else
%             [t, T, names] = walk(child, path + "/" + id, t, T, names);
%         end
%     end
% end
% 
% function printTree(node, indent)
%     ids = string(node.children());
%     for k = 1:numel(ids)
%         fprintf("%s%s\n", indent, ids(k));
%         try, printTree(node.(ids(k)), indent + "  "); catch, end
%     end
% end
% 
% function animateStacks(t, T, cfg, nCols)
%     dx = cfg.cellsPerStack*cfg.cell.thickness; dy = cfg.cell.width; dz = cfg.cell.length; gap = cfg.stackGap;
%     fig = figure("Color","k","Name","Stack-Temperaturen 3D");
%     ax = axes(fig,"Color","k","XColor","w","YColor","w","ZColor","w");
%     hold(ax,"on"); axis(ax,"equal"); grid(ax,"on"); view(ax,35,20);
%     xlabel(ax,"x in m"); ylabel(ax,"y in m"); zlabel(ax,"z in m");
%     colormap(ax,turbo); clim(ax,[min(T(:)) max(T(:))+eps]);
%     cb = colorbar(ax,"Color","w"); cb.Label.String = "T in degC";
%     Vb = [0 0 0;1 0 0;1 1 0;0 1 0;0 0 1;1 0 1;1 1 1;0 1 1] .* [dx dy dz];
%     Fb = [1 2 3 4;5 6 7 8;1 2 6 5;2 3 7 6;3 4 8 7;4 1 5 8];
%     n = size(T,2);  hp = gobjects(1,n);
%     for k = 1:n
%         c = mod(k-1,nCols); r = floor((k-1)/nCols);
%         off = [0, c*(dy+gap), r*(dz+gap)];
%         hp(k) = patch(ax,"Vertices",Vb+off,"Faces",Fb,"FaceColor","flat", ...
%             "FaceVertexCData",T(1,k)*ones(6,1),"EdgeColor",[0.6 0.6 0.6]);
%         text(ax,dx/2,off(2)+dy/2,off(3)+dz+0.01,"S"+k,"Color","w","HorizontalAlignment","center");
%     end
%     ttl = title(ax,"","Color","w");
%     for i = 1:numel(t)
%         for k = 1:n, hp(k).FaceVertexCData = T(i,k)*ones(6,1); end
%         ttl.String = sprintf("t = %.0f s   T_{max} = %.1f degC", t(i), max(T(i,:)));
%         drawnow limitrate;
%     end
% end