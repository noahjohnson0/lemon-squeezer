def score(password: str) -> tuple[int, list[str]]:
    """Return (score, reasons) where:
      - score is an integer 0..4 inclusive (higher = stronger)
      - reasons is a list of lowercase strings explaining what's wrong (or what's strong)
    """
    
    blocklist = ["password", "123456", "12345678", "qwerty", "letmein", "admin", "welcome", "iloveyou", "monkey", "dragon"]
    
    if not password or len(password) < 8:
        return (0, ["too-short"])
    elif password.lower() in [item.lower() for item in blocklist]:
        return (0, ["in-blocklist"])
    
    reasons = []
    score_value = 4
    
    # Check length
    if len(password) >= 16:
        reasons.append("long")
    else:
        score_value -= max(2 - int(len(password) >= 12), 0)
        
    # Check character classes
    lower, upper, digit, symbol = False, False, False, False
    
    for char in password:
        if char.islower():
            lower = True
        elif char.isupper():
            upper = True
        elif char.isdigit():
            digit = True
        else:
            symbol = True
            
    classes_used = sum([int(lower), int(upper), int(digit), int(symbol)])
    
    reasons += [reason for reason, used in zip(["missing-lower", "missing-upper", "missing-digit", "missing-symbol"], [lower, upper, digit, symbol]) if not used]
    
    score_value -= max(2 - classes_used, 0)
    
    # Check consecutive repeats
    repeat_count = 1
    
    for i in range(len(password) - 1):
        if password[i] == password[i + 1]:
            repeat_count += 1
            
            if repeat_count > 3:
                reasons.append("repeats")
                
                score_value -= max(2 - int(score_value >= 3), 0)
                
        else:
            repeat_count = 1
    
    # Check sequences
    for i in range(len(password) - 3):
        sequence = password[i:i+4]
        
        if (sequence.isdigit() and int(sequence[1]) == int(sequence[0]) + 1 and int(sequence[2]) == int(sequence[1]) + 1 and int(sequence[3]) == int(sequence[2]) + 1) or \
           (sequence.isalpha() and ord(sequence[1]) == ord(sequence[0]) + 1 and ord(sequence[2]) == ord(sequence[1]) + 1 and ord(sequence[3]) == ord(sequence[2]) + 1):
            reasons.append("sequence")
            
            score_value -= max(2 - int(score_value >= 4), 0)
    
    return (score_value, reasons)

if __name__ == "__main__":
    print(score("password"))
