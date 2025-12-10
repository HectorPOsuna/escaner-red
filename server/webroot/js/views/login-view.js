/**
 * Login View
 */
export default class LoginView {
    constructor(root, app) {
        this.root = root;
        this.app = app;
        this.render();
    }

    render() {
        this.root.innerHTML = `
            <div class="login-container">
                <div class="login-card">
                    <h2 style="margin-bottom:1.5rem; text-align:center; color:white;">Network Scanner</h2>
                    <form id="login-form">
                        <div class="form-group">
                            <label>Usuario</label>
                            <input type="text" name="username" class="form-input" required>
                        </div>
                        <div class="form-group">
                            <label>Contraseña</label>
                            <input type="password" name="password" class="form-input" required>
                        </div>
                        <button type="submit" class="btn btn-primary" style="width:100%">Iniciar Sesión</button>
                    </form>
                </div>
            </div>
        `;

        this.root.querySelector('#login-form').addEventListener('submit', (e) => this.handleSubmit(e));
    }

    async handleSubmit(e) {
    e.preventDefault();
    const formData = new FormData(e.target);
    const data = Object.fromEntries(formData.entries());
    
    try {
        const res = await fetch('/lisi3309/api/auth/login.php', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(data),
            credentials: 'include'
        });
        
        // 1. Primero verificar el estado HTTP
        console.log("Status:", res.status, "OK?", res.ok);
        
        // 2. Obtener el texto de la respuesta (antes de parsear JSON)
        const responseText = await res.text();
        console.log("Raw response:", responseText);
        
        // 3. Intentar parsear como JSON
        let json;
        try {
            json = JSON.parse(responseText);
        } catch (parseError) {
            console.error("Error parsing JSON:", parseError);
            console.error("Response was:", responseText);
            this.app.toast('Respuesta inválida del servidor', 'danger');
            return;
        }
        
        // 4. Verificar respuesta
        if (res.ok && json.success) {
            this.app.user = json.user;
            this.app.router('/dashboard');
        } else {
            this.app.toast(json.error || 'Error de login', 'danger');
        }
    } catch (err) {
        console.error("Network error:", err);
        this.app.toast('Error de red: ' + err.message, 'danger');
    }
    }
}
