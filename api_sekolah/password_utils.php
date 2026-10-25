<?php
function verify_school_password($provided, $stored)
{
    if (!is_string($provided) || !is_string($stored)) {
        return false;
    }

    if (password_verify($provided, $stored)) {
        return true;
    }

    if (hash_equals($stored, $provided)) {
        return true;
    }

    if (hash_equals($stored, md5($provided))) {
        return true;
    }

    return preg_match('/^[a-f0-9]{32}$/i', $provided) === 1
        && hash_equals($stored, $provided);
}
