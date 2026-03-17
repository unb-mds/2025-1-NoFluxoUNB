<script lang="ts">
	const currentYear = new Date().getFullYear();
</script>

<footer class="border-t bg-background py-8">
	<div class="container mx-auto px-4">
		<div class="flex flex-col items-center justify-between gap-4 md:flex-row">
			<div class="flex items-center space-x-2">
				<span class="text-lg font-bold text-primary">NoFluxo</span>
			</div>

			<div class="text-center">
				<p class="text-xs uppercase tracking-wide text-muted-foreground">Contact Us</p>
				<a href="mailto:unbnofluxo@gmail.com" class="text-sm text-foreground hover:text-primary transition-colors">
					unbnofluxo@gmail.com
				</a>
			</div>

			<p class="text-sm text-muted-foreground">
				© {currentYear} NoFluxo UNB - Todos os direitos reservados
			</p>

			<div class="flex space-x-4">
				<a href="https://github.com/unb-mds/2025-1-NoFluxoUNB" target="_blank" rel="noopener noreferrer" class="text-sm text-muted-foreground hover:text-foreground transition-colors">
					GitHub
				</a>
			</div>
		</div>
	</div>
</footer>
