<?php
// Decide si un cambio de AIDD Lite necesita ADR. Lo usan /aidd-lite:spec, /aidd-lite:build y /aidd-lite:ship.
//
// Uso:
//   php necesita-adr.php ruta1 ruta2 ...   rutas planeadas (spec) o cualquier lista de archivos
//   php necesita-adr.php                   archivos del diff: git diff --name-only origin/main...HEAD
//
// Reglas:
//   - toca código de Shared                                 -> ADR: requerido
//   - toca código de dos o más módulos                      -> ADR: requerido
//   - toca código que no es de ningún módulo (plataforma)   -> ADR: a criterio
//     (lo decide quien corre la skill: ¿cambia algo que usan otras apps?)
//   - todo lo demás                                         -> ADR: no requerido
// Se ignoran docs/, tests/, lockfiles, vendor/ y public/build/: no definen contratos.
// Un ADR es un archivo de docs/adrs/ distinto del README, con la convención de city (ADR-NNN-titulo.md).
//
// Migraciones: city pone el dominio en snake_case en el nombre del archivo (tools__…, add_x_to_contraventional).
// Una migración cuyo nombre no dice el dominio queda a criterio: puede cambiar una tabla que usan otras apps.
// Los archivos de lang/ se asignan por su nombre con el mismo mapa (lang/es/pqrs.php es de pqrs).
// Factories, seeders y archivos de lang/ sin dominio en el nombre heredan el módulo del resto del cambio cuando
// ese resto es de un solo módulo; si no hay de dónde heredar, quedan a criterio.
//
// El mapa de módulos es copia de config/modules.yaml de aidd-metrics (gana el primero que coincide).
// Si cambia allá, se actualiza aquí. El mapa de migraciones y la herencia son propios del kit.

$modulos = [
    'shared' => ['#(^|/)(Shared|shared)/#'],
    'contravencional' => ['#(^|/)(Contraventional|contraventional|Simit|simit)/#', '#^Modules/Infraction/#'],
    'movilidad' => ['#(^|/)(Mobility|mobility)/#'],
    'fotodeteccion' => ['#(^|/)(PhotoTicket|photo-ticket)/#'],
    'billetera-digital' => ['#(^|/)(DigitalWallet|digital-wallet)/#'],
    'tramites' => ['#(^|/)(Procedures|procedures)/#'],
    'archivo-digital' => ['#(^|/)(DigitalArchive|digital-archive)/#'],
    'gestion-cartera' => ['#(^|/)(Collections|collections)/#'],
    'recuperacion-cartera' => ['#(^|/)(PortfolioRecovery|portfolio-recovery)/#'],
    'herramientas' => ['#(^|/)(Tools|ResourceScheduling|resource-scheduling)/#'],
    'paraderos-inteligentes' => ['#(^|/)(SmartStop|smart-stop)/#'],
    'alumbrado-publico' => ['#(^|/)(StreetLight|street-light)/#'],
    'seguridad' => ['#(^|/)(Security|security)/#'],
    'pqrs' => ['#(^|/)(Pqrs|pqrs)/#'],
    'pmt' => ['#(^|/)(Pmt|pmt|TrafficManagementPlan|traffic-management-plan)/#'],
    'sensor-ia' => ['#(^|/)(SensorIA|sensor-ia)/#'],
    'zep' => ['#(^|/)(Zep|zep)/#'],
    'zer' => ['#(^|/)(Zer|zer)/#'],
    'operativos' => ['#(^|/)(Operative|operative)/#'],
    'pantallas' => ['#(^|/)(ScreenManager|screen-manager)/#'],
    'autocheck' => ['#(^|/)(AutoCheck|auto-check)/#'],
];
$migraciones = [
    'shared' => 'shared',
    'contravencional' => 'contraventional|simit',
    'movilidad' => 'mobility',
    'fotodeteccion' => 'photo_ticket',
    'billetera-digital' => 'digital_wallet|ditigal_wallet',
    'tramites' => 'procedures?|proc',
    'archivo-digital' => 'digital_archive',
    'gestion-cartera' => 'collections',
    'recuperacion-cartera' => 'portfolio_recovery',
    'herramientas' => 'tools|resource_scheduling',
    'paraderos-inteligentes' => 'smart_stop',
    'alumbrado-publico' => 'street_light',
    'seguridad' => 'security',
    'pqrs' => 'pqrs',
    'pmt' => 'pmt|traffic_management_plan',
    'sensor-ia' => 'sensor_ia',
    'zep' => 'zep',
    'zer' => 'zer',
    'operativos' => 'operative',
    'pantallas' => 'screen_manager',
    'autocheck' => 'auto_check',
];
$heredan = '#^(database/(factories|seeders)|lang|resources/lang)/#';
$ignorar = '#^(docs|tests)/|(^|/)(composer\.lock|package-lock\.json|yarn\.lock)$|^vendor/|^public/build/#';

$rutas = array_slice($argv, 1);
if ($rutas === []) {
    exec('git diff --name-only origin/main...HEAD 2>/dev/null', $rutas, $codigo);
    if ($codigo !== 0) {
        fwrite(STDERR, "No pude leer el diff contra origin/main. Corre git fetch origin o pasa las rutas.\n");
        exit(3);
    }
}

$adrEnCambio = [];
$porModulo = [];
$plataforma = [];
$sinModuloPropio = [];
foreach ($rutas as $ruta) {
    $ruta = preg_replace('#^\./#', '', trim($ruta));
    if ($ruta === '') {
        continue;
    }
    if (preg_match('#^docs/adrs?/(?!README)[^/]+\.md$#i', $ruta)) {
        $adrEnCambio[] = $ruta;
    }
    if (preg_match($ignorar, $ruta)) {
        continue;
    }
    $encontrados = [];
    foreach ($modulos as $id => $patrones) {
        foreach ($patrones as $patron) {
            if (preg_match($patron, $ruta)) {
                $encontrados[] = $id;
                break 2;
            }
        }
    }
    if ($encontrados === [] && (preg_match('#^database/migrations/(?:\d{4}_\d{2}_\d{2}_\d{6}_)?(.+)\.php$#', $ruta, $m)
        || preg_match('#^(?:resources/)?lang/[^/]+/(.+)\.(php|json)$#', $ruta, $m))) {
        foreach ($migraciones as $id => $tokens) {
            if (preg_match('#(^|_)(' . $tokens . ')(_|$)#', $m[1])) {
                $encontrados[] = $id;
            }
        }
    }
    if ($encontrados !== []) {
        foreach ($encontrados as $id) {
            $porModulo[$id][] = $ruta;
        }
    } elseif (preg_match($heredan, $ruta)) {
        $sinModuloPropio[] = $ruta;
    } else {
        $plataforma[] = $ruta;
    }
}

$enModulos = array_diff(array_keys($porModulo), ['shared']);
if ($sinModuloPropio !== []) {
    if ($plataforma === [] && !isset($porModulo['shared']) && count($enModulos) === 1) {
        $porModulo[reset($enModulos)] = array_merge($porModulo[reset($enModulos)], $sinModuloPropio);
    } else {
        $plataforma = array_merge($plataforma, $sinModuloPropio);
    }
}
if (isset($porModulo['shared'])) {
    $veredicto = 'requerido';
    $motivo = 'toca Shared: ' . implode(', ', array_slice($porModulo['shared'], 0, 5));
} elseif (count($enModulos) >= 2) {
    $veredicto = 'requerido';
    $motivo = 'toca ' . count($enModulos) . ' módulos: ' . implode(', ', $enModulos);
} elseif ($plataforma !== []) {
    $veredicto = 'a criterio';
    $motivo = 'toca código fuera de los módulos; decide si cambia algo que usan otras apps: '
        . implode(', ', array_slice($plataforma, 0, 5));
} else {
    $veredicto = 'no requerido';
    $motivo = $enModulos === [] ? 'no toca código' : 'todo el código es de ' . implode(', ', $enModulos);
}

echo "ADR: {$veredicto}\n";
echo "Motivo: {$motivo}\n";
echo 'Módulos: ' . ($porModulo === [] ? 'ninguno' : implode(', ', array_keys($porModulo))) . "\n";
echo 'ADR en el cambio: ' . ($adrEnCambio === [] ? 'no' : implode(', ', $adrEnCambio)) . "\n";
