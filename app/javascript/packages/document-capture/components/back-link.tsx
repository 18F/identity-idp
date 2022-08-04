import * as React from 'react';

import { Link } from '@18f/identity-components';

interface BackLinkProps extends Omit<React.ComponentProps<typeof Link>,"href"> {
    includeBorder?: boolean;
}

const BackLink: React.FunctionComponent<BackLinkProps> = ({ includeBorder = false, isExternal = false, ...props }) => {
    const linkElement = (
        <Link href='javascript:void 0;' isExternal={isExternal} {...props}>
            &#x2039; Back
        </Link>
    );
    if (includeBorder) {
        return (
            <div className="margin-top-5 padding-top-2 border-top border-primary-light">
            </div>
        );
    } else {
        return linkElement;
    }
}

export default BackLink;