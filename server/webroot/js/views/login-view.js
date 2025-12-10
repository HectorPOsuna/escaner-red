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
            const res = await fetch('api/auth/login.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            
            const json = await res.json();
            
            if (res.ok && json.success) {
                this.app.user = json.user;
                this.app.router('/dashboard');
            } else {
                this.app.toast(json.error || 'Error de login', 'danger');
            }
        } catch (err) {
            this.app.toast('Error de red', 'danger');
        }
    }
}
