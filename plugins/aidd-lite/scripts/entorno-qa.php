<?php
// Confirma que la app que va a probar qa-navegador es local, con la configuración que Laravel usa de verdad
// (incluida la cacheada). Lo corren /aidd-lite:build antes de migrar y el agente qa-navegador antes de probar:
//
//   php artisan tinker --execute "require '<ruta de este archivo>';"
//
// Imprime una línea: "ENTORNO: local (…)" o "ENTORNO: BLOQUEADO: <motivos>".
// AIDD_QA_DB es el nombre de la base local que el dev declaró en .claude/settings.local.json. Evita probar
// contra una base remota que escuche en 127.0.0.1, como un proxy de Cloud SQL o un túnel SSH.

$motivos = [];
$conexion = config('database.default');
$base = config("database.connections.{$conexion}", []);
$locales = ['127.0.0.1', 'localhost', '::1'];

if (! app()->environment('local')) {
    $motivos[] = 'APP_ENV es ' . app()->environment() . ', no local';
}
if (($base['driver'] ?? '') !== 'sqlite' && ! in_array($base['host'] ?? '', $locales, true)) {
    $motivos[] = 'la base no está en esta máquina';
}
$esperada = (string) getenv('AIDD_QA_DB');
$nombre = basename((string) ($base['database'] ?? ''));
if ($esperada === '') {
    $motivos[] = 'falta AIDD_QA_DB en el env de .claude/settings.local.json';
} elseif ($nombre !== $esperada) {
    $motivos[] = "la base es {$nombre} y AIDD_QA_DB dice {$esperada}";
}
$correo = (string) config('mail.default');
$hostCorreo = config("mail.mailers.{$correo}.host");
if (! in_array($correo, ['log', 'array'], true) && ! in_array($hostCorreo, $locales, true)) {
    $motivos[] = "el correo sale por {$correo}";
}

echo $motivos === []
    ? "ENTORNO: local ({$conexion} {$nombre}, correo {$correo}, " . config('app.url') . ")\n"
    : 'ENTORNO: BLOQUEADO: ' . implode('; ', $motivos) . "\n";
