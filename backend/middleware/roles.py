def is_security_guard(user):
    """
    Checks if user is authorized for Security operations.
    """
    if not user or not user.role:
        return False
    return user.role.lower() in ['security', 'guard', 'security_guard', 'admin']

def is_warden(user):
    """
    Checks if user is authorized for Warden operations.
    """
    if not user or not user.role:
        return False
    return user.role.lower() in ['warden', 'admin']

def is_mess_manager(user):
    """
    Authorized mess managers are mess_staff, staff, warden, or admin.
    Students and teachers cannot manage menus or conduct meal verification.
    """
    if not user or not user.role:
        return False
    return user.role.lower() in ['admin', 'staff', 'warden', 'mess_staff', 'mess']

def is_admin(user):
    """
    Checks if user is authorized for Admin operations.
    """
    if not user or not user.role:
        return False
    return user.role.lower() in ['admin', 'administrator', 'superadmin']

