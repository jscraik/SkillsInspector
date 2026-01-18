# brAInwav Brand Compliance Guide

This guide ensures all documentation and artifacts follow brAInwav brand
guidelines when visual formatting is requested or required.

## When Brand Compliance is Required

### Automatic Requirements

- **Root README files** - Always include documentation signature unless user

  opts out

- **Official documentation** - Any documentation representing brAInwav

  publicly

- **Public-facing materials** - Documentation that external users will see

### Optional Applications

- **Visual formatting requests** - When user specifically asks for branded

  styling

- **Internal documentation** - When consistent branding is desired across team

  docs

## Brand Guidelines

### Colors

**Main Colors:**

- **Dark**: `#141413` - Primary text and dark backgrounds
- **Light**: `#faf9f5` - Light backgrounds and text on dark
- **Mid Gray**: `#b0aea5` - Secondary elements
- **Light Gray**: `#e8e6dc` - Subtle backgrounds

**Accent Colors:**

- **Orange**: `#d97757` - Primary accent
- **Blue**: `#6a9bcc` - Secondary accent
- **Green**: `#788c5d` - Tertiary accent

### Typography

- **Headings**: Poppins (with Arial fallback)
- **Body Text**: Lora (with Georgia fallback)
- **Note**: Fonts should be pre-installed in your environment for best results

### Usage Guidelines

**Color Application:**

- Use main colors for text and backgrounds
- Apply accent colors to non-text shapes and highlights
- Cycle through orange, blue, and green accents for visual interest
- Maintain sufficient contrast for accessibility

**Typography Application:**

- Apply Poppins font to headings (24pt and larger)
- Apply Lora font to body text
- Automatically fall back to Arial/Georgia if custom fonts unavailable
- Preserve text hierarchy and formatting

## Required Brand Elements

### Documentation Signature

**For Root README files**, include the documentation signature:

**Image Version (Preferred):**

```markdown
![brAInwav Documentation](brand/brand-mark.png)
```

**ASCII Fallback (if no images):**

```text
┌─────────────────────────────────────┐
│  brAInwav                          │
│  ◆ Intelligent Documentation       │
└─────────────────────────────────────┘
```

### Brand Assets Directory

Ensure `brand/` directory exists with approved assets:

```text
brand/
├── brand-mark.png          # Main logo (512x512)
├── brand-mark@2x.png       # High-DPI version
├── brand-mark.webp         # Web-optimized format
├── brand-mark@2x.webp      # High-DPI web format
└── BRAND_GUIDELINES.md     # This file
```

**Asset Requirements:**

- PNG format for compatibility
- WebP format for web optimization
- 512x512 pixel dimensions for main logo
- @2x versions for high-DPI displays

## Implementation Guidelines

### When to Apply Branding

**Always Apply:**

- Root README files (automatic)
- Public documentation repositories
- Official guides and specifications

**Apply When Requested:**

- Visual formatting requests
- Presentation materials
- Styled documentation exports

**Never Apply:**

- Technical documentation (unless specifically requested)
- Code comments and inline docs
- Internal troubleshooting guides
- Watermarks on any documentation

### Brand Compliance Checklist

#### Required Elements

- [ ] Documentation signature present in root README
- [ ] Brand assets exist in `brand/` directory
- [ ] Assets match approved formats and dimensions
- [ ] No watermarks used in technical documentation

#### Visual Styling (when applicable)

- [ ] Headings use Poppins font (with Arial fallback)
- [ ] Body text uses Lora font (with Georgia fallback)
- [ ] Colors follow approved palette
- [ ] Sufficient contrast maintained for accessibility

#### File Organization

- [ ] Brand assets properly organized in `brand/` directory
- [ ] BRAND_GUIDELINES.md included for reference
- [ ] Asset naming follows convention (brand-mark, @2x variants)

## Automated Validation

### Brand Check Script

If available, run the brand compliance checker manually or use available
linting tools:

```bash
# Manual brand compliance check
# Verify documentation signature is present
# Check brand assets exist in brand/ directory
# Validate color usage against guidelines
```

**Expected Output:**

- Documentation signature verification
- Brand asset presence and format check
- Color usage validation
- Typography compliance check

### Manual Verification

**Documentation Signature:**

1. Check root README for signature presence
2. Verify image displays correctly or ASCII fallback is used
3. Ensure signature is prominently placed (typically at top)

**Brand Assets:**

1. Confirm `brand/` directory exists
2. Verify all required asset formats are present
3. Check file dimensions and quality
4. Validate naming conventions

**Visual Styling:**

1. Review font application (headings vs body text)
2. Check color usage against approved palette
3. Verify accessibility contrast ratios
4. Ensure consistent application across documents

## Installation and Setup

### Installing Brand Guidelines in Repository

If user requests to install brand guidelines:

1. **Copy brand guidelines file:**

```bash # Copy brand guidelines to your repository # Source: Official brAInwav
brand guidelines cp BRAND_GUIDELINES.md brand/BRAND_GUIDELINES.md ```

2. **Copy brand assets:**

```bash # Copy brand assets to your repository # Include: brand-mark.png, @2x

versions, webp formats cp brand-assets/* brand/ ```

3. **Verify installation:**
   - Check that `brand/` directory contains all required files
   - Validate asset formats and dimensions
   - Test documentation signature display

### Font Installation (Optional)

For best results, install brand fonts:

**Poppins Font:**

- Download from Google Fonts or system package manager
- Install system-wide or in application

**Lora Font:**

- Download from Google Fonts or system package manager
- Install system-wide or in application

**Fallback Handling:**

- Arial automatically used if Poppins unavailable
- Georgia automatically used if Lora unavailable
- No installation required for fallback fonts

## Technical Implementation

### Font Management

**System Integration:**

- Uses system-installed Poppins and Lora fonts when available
- Provides automatic fallback to Arial (headings) and Georgia (body)
- No font installation required - works with existing system fonts

**Application Methods:**

- CSS font-family declarations for web content
- Font selection in document processors
- Style templates for consistent application

### Color Application

**RGB Values:**

- Uses precise RGB color values for brand matching
- Applied via appropriate color systems (CSS, design tools)
- Maintains color fidelity across different systems and displays

**Accessibility Compliance:**

- All color combinations meet WCAG 2.1 AA contrast requirements
- Alternative indicators provided where color is used for meaning
- High contrast mode compatibility maintained

## Troubleshooting

### Common Issues

**Documentation Signature Not Displaying:**

- Verify image file exists at specified path
- Check file permissions and accessibility
- Use ASCII fallback if image issues persist
- Ensure proper markdown image syntax

**Brand Assets Missing:**

- Confirm `brand/` directory exists in repository root
- Verify all required asset files are present
- Check file naming matches expected conventions
- Validate file formats (PNG, WebP) and dimensions

**Font Not Applying:**

- Check if Poppins/Lora fonts are installed on system
- Verify font names in CSS/style declarations
- Confirm fallback fonts (Arial/Georgia) are working
- Test font rendering across different platforms

**Color Inconsistencies:**

- Verify RGB values match brand specifications exactly
- Check color profile settings in design tools
- Test color appearance across different displays
- Ensure accessibility contrast requirements are met

### Validation Failures

**Brand Check Script Errors:**

1. Review script output for specific failures
2. Address missing files or incorrect formats
3. Fix color usage violations
4. Update documentation signature if needed

**Manual Review Issues:**

1. Compare against brand guidelines checklist
2. Fix identified compliance gaps
3. Re-validate after corrections
4. Document any approved deviations

## Support and Resources

### Brand Asset Sources

- Official brand asset repository
- Design system documentation
- Brand guidelines reference materials

### Technical Support

- Font installation guides
- Color implementation examples
- Accessibility compliance resources
- Automated validation tools

### Approval Process

- Brand compliance review workflow
- Stakeholder approval requirements
- Documentation of approved exceptions
- Regular brand guideline updates
