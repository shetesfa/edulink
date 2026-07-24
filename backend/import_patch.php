<?php
try {
    $pdo = new PDO('mysql:host=tesfa-edulink.c.aivencloud.com;port=17561;dbname=defaultdb', 'avnadmin', 'YOUR_AIVEN_PASSWORD_HERE');
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $sql = file_get_contents('database/migrations/patch_all_features.sql');
    // Split by statement because PDO::exec might struggle with multiple ALTER TABLE if there is an error in one
    $pdo->exec($sql);
    echo "SUCCESS: Imported patch SQL files.\n";
} catch (Exception $e) {
    echo 'ERROR: ' . $e->getMessage();
}
