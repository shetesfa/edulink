<?php
// A simple viewer to see the latest generated OTP since emails are blocked on Render.
header('Content-Type: text/html; charset=utf-8');
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>EduLink OTP Codes (Debug Mode)</title>
    <style>
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: #0f172a;
            color: #f1f5f9;
            max-width: 500px;
            margin: 80px auto;
            padding: 24px;
            text-align: center;
            border-radius: 20px;
            box-shadow: 0 10px 25px -5px rgba(0, 0, 0, 0.3), 0 8px 10px -6px rgba(0, 0, 0, 0.3);
            border: 1px solid #1e293b;
        }
        h2 {
            color: #c084fc;
            margin-bottom: 8px;
        }
        p {
            color: #94a3b8;
            font-size: 14px;
            margin-bottom: 24px;
        }
        .code-box {
            background: linear-gradient(135deg, #7c3aed 0%, #4f46e5 100%);
            border-radius: 16px;
            padding: 24px;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px rgba(124, 58, 237, 0.4);
        }
        .code {
            font-family: monospace;
            font-size: 48px;
            font-weight: 900;
            letter-spacing: 8px;
            color: #ffffff;
        }
        .meta {
            font-size: 13px;
            color: #94a3b8;
        }
        .email {
            color: #38bdf8;
            font-weight: 600;
        }
        .time {
            color: #34d399;
            font-weight: 600;
        }
        .refresh-btn {
            background: #1e293b;
            border: 1px solid #334155;
            color: #f1f5f9;
            padding: 8px 16px;
            border-radius: 8px;
            cursor: pointer;
            font-size: 13px;
            margin-top: 15px;
            transition: all 0.2s;
        }
        .refresh-btn:hover {
            background: #334155;
        }
    </style>
</head>
<body>
    <h2>🎓 EduLink OTP Viewer</h2>
    <p>Since email ports are blocked on Render, you can find your verification code here:</p>

    <?php
    $file = __DIR__ . '/latest_otp.json';
    if (file_exists($file)) {
        $data = json_decode(file_get_contents($file), true);
        if ($data && (time() - $data['timestamp']) < 600) { // Valid for 10 minutes
            $secondsAgo = time() - $data['timestamp'];
            echo '<div class="code-box">';
            echo '  <div class="code">' . htmlspecialchars($data['code']) . '</div>';
            echo '</div>';
            echo '<div class="meta">';
            echo '  For email: <span class="email">' . htmlspecialchars($data['email']) . '</span><br>';
            echo '  Generated: <span class="time">' . $secondsAgo . ' seconds ago</span>';
            echo '</div>';
        } else {
            echo '<div style="color: #f87171; padding: 20px; border: 1px dashed #f87171; border-radius: 12px; margin-bottom: 20px;">';
            echo '  No active verification codes generated in the last 10 minutes.';
            echo '</div>';
        }
    } else {
        echo '<div style="color: #f87171; padding: 20px; border: 1px dashed #f87171; border-radius: 12px; margin-bottom: 20px;">';
        echo '  No codes have been generated yet.';
        echo '</div>';
    }
    ?>

    <button class="refresh-btn" onclick="window.location.reload()">Refresh Code</button>
</body>
</html>
