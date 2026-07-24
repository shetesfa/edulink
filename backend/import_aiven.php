<?php
try {
    $pdo = new PDO('mysql:host=tesfa-edulink.c.aivencloud.com;port=17561;dbname=defaultdb', 'avnadmin', 'YOUR_AIVEN_PASSWORD_HERE', [
        PDO::MYSQL_ATTR_MULTI_STATEMENTS => true,
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
    
    echo "Dropping all tables...\n";
    $pdo->exec('SET FOREIGN_KEY_CHECKS = 0;');
    $stmt = $pdo->query('SHOW TABLES');
    $tables = $stmt->fetchAll(PDO::FETCH_COLUMN);
    foreach($tables as $table) {
        $pdo->exec("DROP TABLE IF EXISTS `$table`");
        echo "Dropped $table\n";
    }
    $pdo->exec('SET FOREIGN_KEY_CHECKS = 1;');
    
    echo "Importing 001_create_all_tables.sql...\n";
    $sql1 = file_get_contents('database/migrations/001_create_all_tables.sql');
    $sql1 = str_replace('CREATE DATABASE IF NOT EXISTS edulink CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;', '', $sql1);
    $sql1 = str_replace('USE edulink;', '', $sql1);
    $pdo->exec($sql1);
    
    echo "Importing patch_all_features.sql...\n";
    $sql2 = file_get_contents('database/migrations/patch_all_features.sql');
    $sql2 = str_replace('IF NOT EXISTS', '', $sql2); 
    $pdo->exec($sql2);
    
    echo "SUCCESS: Imported SQL files.\n";
} catch (Exception $e) {
    echo 'ERROR: ' . $e->getMessage();
}
