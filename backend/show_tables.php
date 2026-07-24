<?php
try {
    $pdo = new PDO('mysql:host=tesfa-edulink.c.aivencloud.com;port=17561;dbname=defaultdb', 'avnadmin', 'YOUR_AIVEN_PASSWORD_HERE');
    $stmt = $pdo->query('SHOW TABLES');
    print_r($stmt->fetchAll(PDO::FETCH_COLUMN));
} catch (Exception $e) {
    echo 'ERROR: ' . $e->getMessage();
}
