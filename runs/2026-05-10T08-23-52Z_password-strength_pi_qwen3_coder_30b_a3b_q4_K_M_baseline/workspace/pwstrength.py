def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    reasons = []
    
    # Blocklist of common passwords
    blocklist = [
        "password", "123456", "12345678", "qwerty", "letmein", 
        "admin", "welcome", "iloveyou", "monkey", "dragon"
    ]
    
    # Check if password is empty or in blocklist
    if not password or password.lower() in blocklist:
        reasons.append("in-blocklist")
        return (0, reasons)
    
    # Check password length
    length = len(password)
    if length < 8:
        reasons.append("too-short")
        return (0, reasons)
    
    # Count character classes
    has_lower = any(c.islower() for c in password)
    has_upper = any(c.isupper() for c in password)
    has_digit = any(c.isdigit() for c in password)
    has_symbol = any(not c.isalnum() for c in password)
    
    class_count = sum([has_lower, has_upper, has_digit, has_symbol])
    
    # Score calculation
    if length >= 16 and class_count == 4:
        # Check for repeated characters (more than 3 consecutive)
        has_repeats = False
        for i in range(len(password) - 3):
            if password[i] == password[i+1] == password[i+2] == password[i+3]:
                has_repeats = True
                reasons.append("repeats")
                break
                
        if not has_repeats:
            # Check for sequences
            has_sequence = False
            for i in range(len(password) - 3):
                substring = password[i:i+4]
                # Check if substring is a sequence
                if is_sequence(substring):
                    has_sequence = True
                    reasons.append("sequence")
                    break
                
            if not has_sequence:
                return (4, reasons)
    
    if length >= 12:
        if class_count >= 3:
            # Check for repeated characters (more than 3 consecutive)
            has_repeats = False
            for i in range(len(password) - 3):
                if password[i] == password[i+1] == password[i+2] == password[i+3]:
                    has_repeats = True
                    reasons.append("repeats")
                    break
                    
            if not has_repeats:
                return (3, reasons)
        else:
            return (2, reasons)
    elif 8 <= length <= 11:
        if class_count >= 3:
            return (2, reasons)
        else:
            return (1, reasons)
    
    # Default to score 0 if we haven't returned yet
    # This handles the case of length >= 12 but less than 3 classes, etc.
    return (0, reasons)


def is_sequence(s):
    """Check if a string is a sequence of consecutive characters"""
    if len(s) < 4:
        return False
        
    # Check numeric sequences
    if s.isdigit():
        for i in range(len(s) - 1):
            if int(s[i]) + 1 != int(s[i+1]):
                return False
        return True
        
    # Check alphanumeric sequences
    s_lower = s.lower()
    for i in range(len(s) - 1):
        if ord(s_lower[i]) + 1 != ord(s_lower[i+1]):
            return False
    return True