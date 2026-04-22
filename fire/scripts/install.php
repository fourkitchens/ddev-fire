<?php
#ddev-generated

declare(strict_types=1);

$appRoot = $_ENV['DDEV_APPROOT'] ?? '';
if ($appRoot === '') {
    fwrite(STDERR, "DDEV_APPROOT is not available.\n");
    exit(1);
}

$ddevDir = $appRoot . '/.ddev';
$fireDir = $ddevDir . '/fire';
$configFile = $fireDir . '/config.env';

if (!is_dir($fireDir) && !mkdir($fireDir, 0775, true) && !is_dir($fireDir)) {
    fwrite(STDERR, "Unable to create {$fireDir}\n");
    exit(1);
}

$filesToChmod = [
    $ddevDir . '/commands/host/site-build',
    $ddevDir . '/commands/host/site-reset',
    $ddevDir . '/commands/host/frontend-install',
    $ddevDir . '/commands/host/theme-build',
    $ddevDir . '/commands/host/theme-watch',
    $ddevDir . '/commands/host/pull-db',
    $ddevDir . '/commands/host/import-db-reference',
    $ddevDir . '/commands/host/pull-files',
    $ddevDir . '/commands/host/remote-uli',
    $ddevDir . '/commands/host/phpcs',
    $ddevDir . '/commands/host/vscode-xdebug',
    $ddevDir . '/fire/scripts/lib.sh',
];

foreach ($filesToChmod as $file) {
    if (file_exists($file)) {
        @chmod($file, 0775);
    }
}

if (file_exists($configFile)) {
    echo "Keeping existing .ddev/fire/config.env\n";
    exit(0);
}

$mapping = [
    'local_fe_theme_name' => 'FIRE_THEME_NAME',
    'local_theme_build_script' => 'FIRE_THEME_BUILD_SCRIPT',
    'local_theme_watch_script' => 'FIRE_THEME_WATCH_SCRIPT',
    'remote_platform' => 'FIRE_REMOTE_PLATFORM',
    'remote_sitename' => 'FIRE_REMOTE_SITE_NAME',
    'remote_canonical_env' => 'FIRE_REMOTE_CANONICAL_ENV',
];

$merged = [];
foreach ([$appRoot . '/fire.yml', $appRoot . '/fire.local.yml'] as $source) {
    if (!file_exists($source)) {
        continue;
    }
    $parsed = yaml_parse_file($source);
    if (!is_array($parsed)) {
        continue;
    }
    foreach ($mapping as $yamlKey => $envKey) {
        if (array_key_exists($yamlKey, $parsed) && $parsed[$yamlKey] !== null && $parsed[$yamlKey] !== '') {
            $merged[$envKey] = (string) $parsed[$yamlKey];
        }
    }
}

$defaults = [
    'FIRE_THEME_NAME' => '',
    'FIRE_THEME_BUILD_SCRIPT' => 'build',
    'FIRE_THEME_WATCH_SCRIPT' => 'watch',
    'FIRE_REMOTE_PLATFORM' => 'pantheon',
    'FIRE_REMOTE_SITE_NAME' => '',
    'FIRE_REMOTE_CANONICAL_ENV' => 'live',
];

$lines = [
    '#ddev-generated',
    '# Configuration for the ddev-fire add-on.',
    '# Edit this file for ongoing project-specific customization.',
    '',
];

if ($merged !== []) {
    $values = array_replace($defaults, $merged);
    foreach ($values as $key => $value) {
        $lines[] = sprintf('%s="%s"', $key, addcslashes($value, "\\\""));
    }
    $lines[] = '';
    $lines[] = '# Values above were imported from fire.yml / fire.local.yml.';
} else {
    $lines[] = '# Uncomment and adjust values as needed.';
    foreach ($defaults as $key => $value) {
        $lines[] = sprintf('# %s="%s"', $key, addcslashes($value, "\\\""));
    }
}

$content = implode(PHP_EOL, $lines) . PHP_EOL;
if (file_put_contents($configFile, $content) === false) {
    fwrite(STDERR, "Unable to write {$configFile}\n");
    exit(1);
}

echo "Created .ddev/fire/config.env\n";
