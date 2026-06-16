#!/usr/bin/env ruby
require "bundler/setup"
require "forki"

Capybara.default_max_wait_time = 5  # Reducir de 60s a 5s para evitar cuelgues

scraper = Forki::PostScraper.new
page = scraper.send(:page)

puts "Haciendo login..."
scraper.send(:login)
puts "Login completado. Logged in: #{scraper.logged_in}"
puts "Página: #{page.title}"
sleep(5)

# Buscar campo de código de seguridad
puts "\nBuscando campo de código de seguridad..."
code_field = nil
['input[name="approvals_code"]', 'input[id="approvals_code"]',
 'input[autocomplete="one-time-code"]', 'input[type="text"]'].each do |sel|
  begin
    code_field = page.find(sel, wait: 2)
    puts "Campo encontrado: #{sel}"
    break
  rescue Capybara::ElementNotFound; end
end

if code_field
  print "\n*** Introduce el código de seguridad: "
  $stdout.flush
  code = $stdin.gets.chomp

  code_field.set(code)
  sleep(1)

  puts "Enviando código (Enter)..."
  code_field.send_keys(:return)
  sleep(5)

  puts "Tras enviar - Página: #{page.title}"
  puts "URL: #{page.current_url}"

  # Manejar "Save this browser?" u otros prompts
  begin
    btns = page.all(:xpath, '//*[@role="button"]', wait: 3)
    btns.each { |b| puts "  Botón visible: '#{b.text.strip}'" }
    ok = btns.find { |b| b.text.strip =~ /ok|save|continue|not now/i }
    ok&.click
    sleep(3)
  rescue => e
    puts "Sin prompts adicionales"
  end

  puts "\nEstado final:"
  puts "  Página: #{page.title}"
  puts "  URL: #{page.current_url}"
else
  puts "No se encontró campo de código"
end

puts "\nGuardando cookies..."
cookies = page.driver.browser.manage.all_cookies
File.write("forki_cookies.json", cookies.to_json)
puts "Guardadas #{cookies.count} cookies."

page.quit
puts "Listo."
