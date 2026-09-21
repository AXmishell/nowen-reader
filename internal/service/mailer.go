package service

import (
	"errors"
	"fmt"
	"html"
	"time"

	"github.com/wneessen/go-mail"

	"github.com/nowen-reader/nowen-reader/internal/config"
)

// ErrSMTPNotConfigured is returned when outbound email is disabled or missing a host.
var ErrSMTPNotConfigured = errors.New("SMTP 未配置")

// smtpTimeout bounds a single SMTP transaction so auth flows never hang forever.
const smtpTimeout = 15 * time.Second

// 邮箱验证码有效期，与 handler 侧 TTL 保持一致（10 分钟）。
const mailerCodeTTLMinutes = 10

// emailMessage is the content of one outbound message.
type emailMessage struct {
	to      string
	subject string
	text    string
	html    string
}

// IsConfigured reports whether outbound email is enabled and has a host configured.
func IsConfigured() bool {
	return config.IsSMTPEnabled()
}

// SendVerificationCode delivers a one-time code for the given purpose.
// purpose "verify" renders an email-verification message; "login" renders a
// login-code message. The code is valid for 10 minutes.
func SendVerificationCode(to, code, purpose string) error {
	if !IsConfigured() {
		return ErrSMTPNotConfigured
	}
	subject, textBody, htmlBody := verificationCodeContent(purpose, code)
	return sendMail(config.GetSMTP(), emailMessage{to: to, subject: subject, text: textBody, html: htmlBody})
}

// SendTestEmail sends a simple message so admins can validate SMTP settings.
func SendTestEmail(to string) error {
	if !IsConfigured() {
		return ErrSMTPNotConfigured
	}
	siteName := config.GetSiteName()
	textBody := fmt.Sprintf("%s SMTP 配置测试成功。\n\n这是一封测试邮件，收到即表示您的邮件服务配置可用。", siteName)
	htmlBody := fmt.Sprintf(
		`<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;line-height:1.6;color:#333;">
	<h2 style="margin:0 0 12px;">%s</h2>
	<p style="margin:0 0 8px;">SMTP 配置测试成功。</p>
	<p style="margin:0;color:#888;font-size:13px;">这是一封测试邮件，收到即表示您的邮件服务配置可用。</p>
</div>`, html.EscapeString(siteName))
	return sendMail(config.GetSMTP(), emailMessage{
		to:      to,
		subject: fmt.Sprintf("[%s] SMTP 测试邮件", siteName),
		text:    textBody,
		html:    htmlBody,
	})
}

// verificationCodeContent builds the subject, plain-text and HTML bodies for a
// verification/login code email.
func verificationCodeContent(purpose, code string) (subject, textBody, htmlBody string) {
	siteName := config.GetSiteName()
	action := "邮箱验证"
	switch purpose {
	case "login":
		action = "登录验证码"
	case "bind":
		action = "邮箱绑定"
	}

	subject = fmt.Sprintf("[%s] %s", siteName, action)
	textBody = fmt.Sprintf(
		"%s\n\n您正在进行%s操作，验证码为：%s\n\n验证码 %d 分钟内有效，请勿泄露给他人。\n若非本人操作，请忽略本邮件。",
		siteName, action, code, mailerCodeTTLMinutes,
	)
	htmlBody = fmt.Sprintf(
		`<div style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;line-height:1.6;color:#333;">
	<h2 style="margin:0 0 12px;">%s</h2>
	<p style="margin:0 0 8px;">您正在进行%s操作，验证码为：</p>
	<p style="margin:12px 0;font-size:28px;font-weight:700;letter-spacing:6px;color:#111;">%s</p>
	<p style="margin:0;color:#888;font-size:13px;">验证码 %d 分钟内有效，请勿泄露给他人。若非本人操作，请忽略本邮件。</p>
	</div>`, html.EscapeString(siteName), action, code, mailerCodeTTLMinutes)
	return subject, textBody, htmlBody
}

// sendMail builds and dispatches one message over the configured SMTP transport.
func sendMail(cfg config.SMTPConfig, m emailMessage) error {
	from := cfg.From
	if from == "" {
		from = cfg.Username
	}
	if from == "" {
		return errors.New("SMTP 发件人地址未配置")
	}

	msg := mail.NewMsg()
	if cfg.FromName != "" {
		if err := msg.FromFormat(cfg.FromName, from); err != nil {
			return fmt.Errorf("SMTP 发件人地址无效: %w", err)
		}
	} else if err := msg.From(from); err != nil {
		return fmt.Errorf("SMTP 发件人地址无效: %w", err)
	}
	if err := msg.To(m.to); err != nil {
		return fmt.Errorf("收件地址无效: %w", err)
	}
	msg.Subject(m.subject)
	msg.SetBodyString(mail.TypeTextPlain, m.text)
	msg.AddAlternativeString(mail.TypeTextHTML, m.html)

	opts := []mail.Option{
		mail.WithPort(cfg.Port),
		mail.WithTimeout(smtpTimeout),
	}
	if cfg.Username != "" {
		opts = append(opts,
			mail.WithSMTPAuth(mail.SMTPAuthPlain),
			mail.WithUsername(cfg.Username),
			mail.WithPassword(cfg.Password),
		)
	} else {
		opts = append(opts, mail.WithSMTPAuth(mail.SMTPAuthNoAuth))
	}

	switch cfg.TLSMode {
	case "none":
		opts = append(opts, mail.WithTLSPolicy(mail.NoTLS))
	case "ssl":
		opts = append(opts, mail.WithSSL())
	default: // "starttls"
		opts = append(opts, mail.WithTLSPolicy(mail.TLSMandatory))
	}

	client, err := mail.NewClient(cfg.Host, opts...)
	if err != nil {
		return fmt.Errorf("初始化 SMTP 客户端失败: %w", err)
	}
	if err := client.DialAndSend(msg); err != nil {
		return fmt.Errorf("发送邮件失败: %w", err)
	}
	return nil
}
