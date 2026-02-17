import { z } from 'zod';

export const loginSchema = z.object({
	email: z
		.string({ error: 'Por favor, insira seu e-mail' })
		.min(1, 'Por favor, insira seu e-mail')
		.email('E-mail inválido')
		.refine(
			(email) => {
				const parts = email.split('@');
				if (parts.length !== 2 || !parts[1]) return false;
				if (!parts[1].includes('.')) return false;
				if (parts[1].startsWith('.') || parts[1].endsWith('.')) return false;
				return true;
			},
			'Inclua um domínio válido após o "@" (ex: gmail.com)'
		),
	password: z
		.string({ error: 'Por favor, insira sua senha' })
		.min(1, 'Por favor, insira sua senha'),
	rememberMe: z.boolean().default(false)
});

export const signupSchema = z
	.object({
		name: z
			.string({ error: 'Por favor, insira seu nome' })
			.min(3, 'Nome deve ter pelo menos 3 caracteres')
			.refine((name) => name.trim().split(/\s+/).length >= 2, 'Insira nome e sobrenome'),
		email: z
			.string({ error: 'Por favor, insira seu e-mail' })
			.min(1, 'Por favor, insira seu e-mail')
			.email('E-mail inválido')
			.refine(
				(email) => {
					const parts = email.split('@');
					if (parts.length !== 2 || !parts[1]) return false;
					if (!parts[1].includes('.')) return false;
					if (parts[1].startsWith('.') || parts[1].endsWith('.')) return false;
					return true;
				},
				'Inclua um domínio válido após o "@" (ex: gmail.com)'
			),
		password: z
			.string({ error: 'Por favor, insira sua senha' })
			.min(8, 'A senha deve ter pelo menos 8 caracteres'),
		confirmPassword: z
			.string({ error: 'Por favor, confirme sua senha' })
			.min(1, 'Por favor, confirme sua senha'),
		acceptTerms: z
			.boolean()
			.refine((val) => val === true, 'Você deve aceitar os Termos de Serviço')
	})
	.refine((data) => data.password === data.confirmPassword, {
		message: 'As senhas não coincidem',
		path: ['confirmPassword']
	});

export const passwordRecoverySchema = z.object({
	email: z
		.string({ error: 'Por favor, insira seu e-mail' })
		.min(1, 'Por favor, insira seu e-mail')
		.email('E-mail inválido')
});

/** Password strength requirements for the signup form */
export const passwordRequirements = [
	{ label: 'Pelo menos 8 caracteres', test: (pw: string) => pw.length >= 8 },
	{ label: 'Letra maiúscula', test: (pw: string) => /[A-Z]/.test(pw) },
	{ label: 'Letra minúscula', test: (pw: string) => /[a-z]/.test(pw) },
	{ label: 'Número', test: (pw: string) => /[0-9]/.test(pw) },
	{ label: 'Caractere especial (!@#$&*~)', test: (pw: string) => /[!@#$&*~]/.test(pw) }
] as const;

export type LoginFormData = z.infer<typeof loginSchema>;
export type SignupFormData = z.infer<typeof signupSchema>;
export type PasswordRecoveryFormData = z.infer<typeof passwordRecoverySchema>;
